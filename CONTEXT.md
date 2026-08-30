# Serialbench domain glossary

- **Adapter** (a.k.a. serializer): one Ruby serialization library under measurement (nokogiri, leptris, oj, psych, toml-rb…). Registered per format in `Serializers::Serializers::REGISTER`. Its interface is the **capability set** (`capabilities` → `Set<Symbol>`); the `features` hash export derives from it.
- **Format**: xml, json, yaml, toml. One adapter belongs to exactly one format; one format has several adapters.
- **Operation**: one measured workload — `parsing`, `generation`, `xpath`, `streaming` (the `OPERATIONS` table in `BenchmarkRunner`), plus `memory` (profiled separately). Config `operations:` uses exactly these names; absent = run all; unknown name = error.
- **Result Leg**: one platform × ruby × format benchmark execution (one process, one config file). Produces one `results.yaml`.
- **Data Run**: one dated directory in the data repo (`runs/YYYY-MM-DD/`), holding one YAML file per environment × format. Append-only; the site's aggregator takes the latest run's data per environment.
- **Environment**: where a leg executes — `local`, `docker`, or `asdf` (`kind` in the environment config). Dispatched through `Runners.for`.
- **Environment key**: `{platform}-ruby-{version}` (e.g. `macos-26-ruby-3.4`) — the site's identity for a platform×ruby pair.
- **Capability**: a symbol in an adapter's capability set (`:xpath`, `:sax`, `:stax`, `:generate`, `:namespaces`…). Benchmarks filter adapters by capability; the site renders them as the capability strip.
- **Data push**: one Result Leg's results.yaml written to the data repo via the Contents API (atomic, per-format).
- **Fixture**: the generated test document for a format × size (`small`/`medium`/`large`), built by `Serialbench::TestData`. `test_data/{size}.{format}` files override the generated one.
