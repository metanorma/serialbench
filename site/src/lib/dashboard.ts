// Typed access to the dashboard payload produced by the Ruby CLI
// (`serialbench resultset export-data` — same shape the old Liquid site
// consumed): combined_results[op][size][format][serializer][envKey].

export interface PerfMetric {
  iterations_per_second: number;
  time_per_iteration: number;
}

export interface MemoryMetric {
  allocated_memory: number;
  retained_memory: number;
}

export interface Environment {
  ruby_version: string;
  ruby_platform?: string;
  os: string;
  arch: string;
  timestamp: string;
  source_file?: string;
}

export interface Payload {
  combined_results: Record<string, Record<string, Record<string, Record<string, Record<string, PerfMetric | MemoryMetric>>>>>;
  environments: Record<string, Environment>;
  metadata: {
    resultset_name?: string;
    resultset_description?: string;
    total_runs?: number;
    generated_at: string;
  };
}

export const OPERATIONS = ['parsing', 'generation', 'streaming'] as const;
export type Operation = (typeof OPERATIONS)[number];

export const OPERATION_LABELS: Record<Operation, string> = {
  parsing: 'Parse',
  generation: 'Generate',
  streaming: 'Stream',
};

export type Size = 'small' | 'medium' | 'large';

export interface LeaderRow {
  serializer: string;
  ips: number;
  msPerIteration: number;
  ratioToRef: number | null;
}

function metricsFor(payload: Payload, op: string, size: string, format: string): Record<string, Record<string, PerfMetric>> {
  const byFormat = payload.combined_results[op]?.[size]?.[format] ?? {};
  return byFormat as Record<string, Record<string, PerfMetric>>;
}

const FORMAT_ORDER = ['xml', 'json', 'yaml', 'toml'];

export function availableFormats(payload: Payload): string[] {
  const formats = new Set<string>();
  for (const sizes of Object.values(payload.combined_results.parsing ?? {})) {
    for (const format of Object.keys(sizes)) formats.add(format);
  }
  return [...formats].sort((a, b) => {
    const ia = FORMAT_ORDER.indexOf(a);
    const ib = FORMAT_ORDER.indexOf(b);
    return (ia === -1 ? FORMAT_ORDER.length : ia) - (ib === -1 ? FORMAT_ORDER.length : ib);
  });
}

export function availableOperations(payload: Payload, format: string): Operation[] {
  return OPERATIONS.filter((op) => {
    const sizes = payload.combined_results[op];
    if (!sizes) return false;
    return Object.values(sizes).some((byFormat) => format in byFormat);
  });
}

export function availableSizes(payload: Payload, op: string, format: string): string[] {
  const sizes = payload.combined_results[op];
  if (!sizes) return [];
  return Object.keys(sizes).filter((size) => {
    const byFormat = sizes[size];
    return byFormat != null && format in byFormat && Object.keys(byFormat[format]).length > 0;
  });
}

export function environmentList(payload: Payload): { key: string; env: Environment }[] {
  return Object.entries(payload.environments)
    .map(([key, env]) => ({ key, env }))
    .sort((a, b) => b.env.timestamp.localeCompare(a.env.timestamp));
}

// Env keys are runner-shaped ("macos-26-intel-ruby-3.4") when produced by CI,
// or "macos-arm64-ruby-3.4" (os-arch) for docker/local/legacy results.
export function environmentLabel(key: string, env: Environment): string {
  const arch = env.arch === 'x86_64' ? 'x64' : env.arch;
  const runner = key.replace(/-ruby-[^-]*$/, '');
  const m = runner.match(/^(ubuntu|macos|windows)-(\d+(?:\.\d+)?)(?:-(arm|intel|large))?$/);
  if (m) {
    const osName = m[1].replace('ubuntu', 'Ubuntu').replace('windows', 'Windows').replace('macos', 'macOS');
    const variant = m[3] === 'intel' ? ' Intel' : '';
    return `${osName} ${m[2]}${variant} · ${arch} · Ruby ${env.ruby_version}`;
  }
  const osName = env.os.replace('ubuntu', 'Ubuntu').replace('windows', 'Windows').replace('macos', 'macOS');
  return `${osName} · ${arch} · Ruby ${env.ruby_version}`;
}

// Short runner label for table headers: "macos-26-intel-ruby-3.4" → "macOS 26 Intel"
export function runnerShortLabel(key: string, env: Environment): string {
  const runner = key.replace(/-ruby-[^-]*$/, '');
  const m = runner.match(/^(ubuntu|macos|windows)-(\d+(?:\.\d+)?)(?:-(arm|intel|large))?$/);
  if (m) {
    const osName = m[1].replace('ubuntu', 'Ubuntu').replace('windows', 'Windows').replace('macos', 'macOS');
    return `${osName} ${m[2]}${m[3] === 'intel' ? ' Intel' : ''}`;
  }
  return runner || env.os;
}

export function serializersFor(payload: Payload, format: string): string[] {
  const serializers = new Set<string>();
  for (const sizes of Object.values(payload.combined_results.parsing ?? {})) {
    if (format in sizes) Object.keys(sizes[format]).forEach((s) => serializers.add(s));
  }
  for (const sizes of Object.values(payload.combined_results.generation ?? {})) {
    if (format in sizes) Object.keys(sizes[format]).forEach((s) => serializers.add(s));
  }
  return [...serializers].sort();
}

/** Ranking at one operation/size/env; ratios computed against `reference`. */
export function leaderboard(payload: Payload, op: string, size: string, format: string, envKey: string, reference: string | null): LeaderRow[] {
  const bySerializer = metricsFor(payload, op, size, format);
  const rows: LeaderRow[] = [];
  for (const [serializer, byEnv] of Object.entries(bySerializer)) {
    const metric = byEnv[envKey];
    if (!metric || metric.iterations_per_second == null) continue;
    rows.push({
      serializer,
      ips: metric.iterations_per_second,
      msPerIteration: metric.time_per_iteration * 1000,
      ratioToRef: null,
    });
  }
  rows.sort((a, b) => b.ips - a.ips);
  const ref = rows.find((r) => r.serializer === reference) ?? rows[0];
  if (ref) {
    for (const row of rows) row.ratioToRef = row.ips > 0 ? ref.ips / row.ips : null;
  }
  return rows;
}

export interface MemoryRow {
  serializer: string;
  allocated: number;
  retained: number;
}

export function memoryRows(payload: Payload, size: string, format: string, envKey: string): MemoryRow[] {
  const bySerializer = metricsFor(payload, 'memory', size, format);
  const rows: MemoryRow[] = [];
  for (const [serializer, byEnv] of Object.entries(bySerializer)) {
    const metric = byEnv[envKey] as MemoryMetric | undefined;
    if (!metric || metric.allocated_memory == null) continue;
    rows.push({ serializer, allocated: metric.allocated_memory, retained: metric.retained_memory });
  }
  return rows.sort((a, b) => a.allocated - b.allocated);
}

/** serializer × env coverage — "will it run on my stack", derived from the data itself. */
export function availability(payload: Payload): { serializers: string[]; envKeys: string[]; cells: Map<string, Set<string>> } {
  const serializers = new Set<string>();
  const cells = new Map<string, Set<string>>();
  for (const [op, sizes] of Object.entries(payload.combined_results)) {
    if (op === 'memory') continue;
    for (const byFormat of Object.values(sizes)) {
      for (const bySerializer of Object.values(byFormat)) {
        for (const [serializer, byEnv] of Object.entries(bySerializer)) {
          serializers.add(serializer);
          if (!cells.has(serializer)) cells.set(serializer, new Set());
          for (const envKey of Object.keys(byEnv)) cells.get(serializer)!.add(envKey);
        }
      }
    }
  }
  const envKeys = Object.keys(payload.environments);
  return { serializers: [...serializers].sort(), envKeys, cells };
}

export function formatIps(ips: number): string {
  if (ips >= 1000) return `${(ips / 1000).toFixed(ips >= 10000 ? 0 : 1)}k`;
  if (ips >= 100) return ips.toFixed(0);
  if (ips >= 10) return ips.toFixed(1);
  return ips.toFixed(2);
}

export function formatMemory(mb: number): string {
  if (mb >= 1000) return `${(mb / 1000).toFixed(2)} GB`;
  if (mb >= 1) return `${mb.toFixed(1)} MB`;
  return `${(mb * 1024).toFixed(0)} KB`;
}

export function primaryEnvKey(payload: Payload): string {
  return environmentList(payload)[0]?.key ?? '';
}

export interface LibraryStat {
  op: string;
  size: string;
  ips: number;
  rank: number;
  fieldSize: number;
  bestSerializer: string;
  ratioToBest: number | null;
}

/** All measured stats for one serializer on the primary environment. */
export function libraryStats(payload: Payload, serializer: string, envKey: string): LibraryStat[] {
  const stats: LibraryStat[] = [];
  for (const [op, sizes] of Object.entries(payload.combined_results)) {
    if (op === 'memory') continue;
    for (const [size, formats] of Object.entries(sizes)) {
      for (const bySerializer of Object.values(formats)) {
        if (!(serializer in bySerializer)) continue;
        const metric = bySerializer[serializer][envKey] as PerfMetric | undefined;
        if (!metric || metric.iterations_per_second == null) continue;
        const best = Object.entries(bySerializer)
          .map(([name, byEnv]) => ({ name, ips: (byEnv[envKey] as PerfMetric | undefined)?.iterations_per_second ?? 0 }))
          .sort((a, b) => b.ips - a.ips);
        const ips = metric.iterations_per_second;
        stats.push({
          op,
          size,
          ips,
          rank: best.findIndex((b) => b.name === serializer) + 1,
          fieldSize: best.length,
          bestSerializer: best[0].name,
          ratioToBest: best[0].ips > 0 ? best[0].ips / ips : null,
        });
      }
    }
  }
  return stats;
}

/** Formats a serializer participated in. */
export function formatsForSerializer(payload: Payload, serializer: string): string[] {
  const formats = new Set<string>();
  for (const sizes of Object.values(payload.combined_results.parsing ?? {})) {
    for (const [format, bySerializer] of Object.entries(sizes)) {
      if (serializer in bySerializer) formats.add(format);
    }
  }
  for (const sizes of Object.values(payload.combined_results.generation ?? {})) {
    for (const [format, bySerializer] of Object.entries(sizes)) {
      if (serializer in bySerializer) formats.add(format);
    }
  }
  return [...formats].sort();
}
