// Generates src/data/sample.json in the exact shape the Ruby CLI's
// resultset export will produce: combined_results[op][size][format][serializer][envKey]
// plus environments{} and metadata{}. Numbers are anchored to the real
// 2026-08-23 local race (leptris 1.1.0, macOS arm64, Ruby 3.4.8) and scaled
// per environment with deterministic factors -- plausible, never random.
//
// In CI the real payload replaces this file before `astro build`.

import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const outPath = join(here, '..', 'src', 'data', 'sample.json');

const envs = [
  { key: 'macos-arm64-ruby-3.4', os: 'macos', arch: 'arm64', ruby: '3.4', factor: 1.0 },
  { key: 'macos-x86_64-ruby-3.4', os: 'macos', arch: 'x86_64', ruby: '3.4', factor: 0.62 },
  { key: 'linux-arm64-ruby-3.4', os: 'ubuntu-24.04', arch: 'arm64', ruby: '3.4', factor: 0.88 },
  { key: 'linux-x86_64-ruby-3.3', os: 'ubuntu-24.04', arch: 'x86_64', ruby: '3.3', factor: 0.79 },
  { key: 'linux-x86_64-ruby-3.2', os: 'ubuntu-22.04', arch: 'x86_64', ruby: '3.2', factor: 0.71 },
];

// Base rates in iterations/second on the reference env (macos arm64, ruby 3.4).
// [small, medium, large]
const base = {
  xml: {
    leptris: { parsing: [8400, 1190, 123], generation: [7400, 746, 12.4], streaming: [12400, 1695, 68] },
    nokogiri: { parsing: [1900, 204, 9.9], generation: [3100, 125, 11.3], streaming: [1500, 20.7, 4.7] },
    ox: { parsing: [2600, 278, 9.9], generation: [5200, 192, 8.0], streaming: [1100, 9.3, 6.3] },
    oga: { parsing: [720, 71, 3.1], generation: [1400, 58, 2.4], streaming: [420, 5.4, 1.9] },
    rexml: { parsing: [410, 39, 1.6], generation: [900, 34, 1.1], streaming: [260, 3.1, 1.2] },
    'libxml-ruby': { parsing: [2300, 255, 12.1], generation: [2900, 118, 10.8], streaming: [null, null, null] },
  },
  json: {
    oj: { parsing: [9600, 1580, 96], generation: [11200, 1350, 88] },
    rapidjson: { parsing: [8900, 1420, 91], generation: [9400, 1180, 79] },
    json: { parsing: [5200, 690, 51], generation: [6100, 705, 47] },
    yajl: { parsing: [6100, 830, 58], generation: [6800, 910, 62] },
  },
  yaml: {
    psych: { parsing: [2100, 230, 15], generation: [2400, 210, 12] },
  },
  toml: {
    tomlib: { parsing: [3600, 430, 27], generation: [4100, 470, 31] },
    'toml-rb': { parsing: [1300, 140, 9], generation: [1700, 160, 11] },
    tomlrb: { parsing: [2400, 300, 19], generation: [null, null, null] },
  },
};

// Allocated MB during parse of the large document, reference env.
const memoryLarge = {
  xml: { leptris: 0.01, nokogiri: 539.9, ox: 237.4, oga: 612.0, rexml: 890.5, 'libxml-ruby': 301.2 },
  json: { oj: 82.0, rapidjson: 96.0, json: 168.0, yajl: 142.0 },
  yaml: { psych: 210.0 },
  toml: { tomlib: 190.0, 'toml-rb': 420.0, tomlrb: 355.0 },
};

// libs unavailable per env (glibc / platform gaps) -- mirrors real coverage
const unavailable = new Set([
  'linux-x86_64-ruby-3.2|xml|leptris', // ubuntu-22.04 glibc: precompiled gem skips
  'linux-x86_64-ruby-3.2|xml|libxml-ruby',
  'macos-arm64-ruby-3.4|toml|tomlrb',
]);

const sizes = ['small', 'medium', 'large'];
const sizeScale = { small: 1.0, medium: 0.16, large: 0.02 };
const memRetainedRatio = 0.22;

const combined = {};
const environments = {};

for (const env of envs) {
  environments[env.key] = {
    ruby_version: env.ruby,
    ruby_platform: `${env.arch}-${env.os.startsWith('macos') ? 'darwin' : 'linux'}`,
    os: env.os,
    arch: env.arch,
    timestamp: '2026-08-23T09:00:00Z',
    source_file: `data/${env.key}.yaml`,
  };

  for (const [format, serializers] of Object.entries(base)) {
    for (const [serializer, ops] of Object.entries(serializers)) {
      if (unavailable.has(`${env.key}|${format}|${serializer}`)) continue;

      for (const [op, rates] of Object.entries(ops)) {
        rates.forEach((ips, i) => {
          if (ips == null) return;
          const size = sizes[i];
          combined[op] ??= {};
          combined[op][size] ??= {};
          combined[op][size][format] ??= {};
          combined[op][size][format][serializer] ??= {};
          const scaled = ips * env.factor;
          combined[op][size][format][serializer][env.key] = {
            iterations_per_second: Number(scaled.toFixed(scaled < 10 ? 2 : 1)),
            time_per_iteration: Number((1000 / scaled).toFixed(4)),
          };
        });
      }

      const mem = memoryLarge[format]?.[serializer];
      if (mem != null) {
        combined.memory ??= {};
        for (const size of sizes) {
          const factor = size === 'large' ? 1 : size === 'medium' ? 0.14 : 0.012;
          combined.memory[size] ??= {};
          combined.memory[size][format] ??= {};
          combined.memory[size][format][serializer] ??= {};
          const allocated = mem * env.factor * factor;
          combined.memory[size][format][serializer][env.key] = {
            allocated_memory: Number(allocated.toFixed(2)),
            retained_memory: Number((allocated * memRetainedRatio).toFixed(2)),
          };
        }
      }
    }
  }
}

const payload = {
  combined_results: combined,
  environments,
  metadata: {
    resultset_name: 'weekly-benchmark',
    resultset_description: 'Sample data for development; CI replaces this with the live resultset',
    total_runs: envs.length,
    generated_at: '2026-08-23T09:00:00Z',
  },
};

mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, JSON.stringify(payload, null, 2) + '\n');
console.log(`wrote ${outPath} (${envs.length} environments)`);
