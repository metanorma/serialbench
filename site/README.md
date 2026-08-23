# serialbench site

The benchmark console at https://metanorma.github.io/serialbench/.

Astro 7 (Vite 8) with Vue islands and Tailwind 4. Charts are Chart.js 4,
bundled — no CDN.

## Develop

```
npm install
npm run generate:sample-data   # writes src/data/sample.json (gitignored)
npm run dev                    # http://localhost:4321/serialbench/
```

`src/data/sample.json` is generated from the race numbers in
`scripts/gen-sample-data.mjs` and is ignored by git. In CI the real payload
(written by `serialbench resultset export-data`) replaces it before
`astro build`; the shape is identical — see `src/lib/dashboard.ts`.

## Data contract

```
combined_results[op][size][format][serializer][envKey] = {
  iterations_per_second, time_per_iteration   # perf ops
  allocated_memory, retained_memory            # op == "memory"
}
environments[envKey] = { ruby_version, os, arch, timestamp, ... }
metadata = { resultset_name, total_runs, generated_at }
```

Missing entries mean "not measured on that leg" — never zero.
