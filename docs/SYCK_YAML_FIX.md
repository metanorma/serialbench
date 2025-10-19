# Syck YAML Constant Fix

## Problem Summary

GitHub Actions workflow failed with cryptic error:
```
Error adding run to resultset: undefined method `platform_string' for nil
```

Root cause: Benchmark results.yaml files were only 2 bytes containing `{}` instead of the expected ~10KB files with complete benchmark data.

## Root Cause Analysis

After 4 rounds of progressive fixes, we discovered the Syck gem was overriding the YAML constant, causing Lutaml::Model's `to_yaml` method to produce empty output.

### Fix Timeline

1. **Fix #1 (Commit 53f1799)**: Corrected `memory_usage` → `memory` attribute name
   - Result: Still produced empty `{}` files

2. **Fix #2 (Commit fcd23f2)**: Added key_value blocks to BenchmarkResult models
   - Result: Still produced empty `{}` files

3. **Fix #3 (Commit d8fb78b)**: Added key_value blocks to all remaining models
   - Result: Still produced empty `{}` files

4. **Fix #4 (Commit 69a2bd7)**: **Restored YAML constant to Psych in LocalRunner**
   - Result: ✅ **SUCCESS! 10KB files with complete data**

## The Critical Fix

Added to `lib/serialbench/runners/local_runner.rb`:

```ruby
# Restore YAML to use Psych for output, otherwise lutaml-model's to_yaml
# will have no output (Syck gem overrides YAML constant)
Object.const_set(:YAML, Psych)

results_file = File.join(result_dir, 'results.yaml')
results_model.to_file(results_file)
```

## Why This Happened

- The `_docker_execute` method in `benchmark_cli.rb` already had this fix (lines 151-154)
- Local testing with `serialbench benchmark _docker_execute` worked fine
- GHA with `serialbench environment execute` (uses LocalRunner) failed
- The Syck gem overrides the YAML constant during benchmark execution
- Without restoring it to Psych, Lutaml::Model serialization produces empty output

## Verification

From successful GHA run #51:

```
File size: 10258 bytes
✅ File size OK: 10258 bytes
✅ YAML syntax valid

---
platform:
  platform_string: local-3.4.7
  kind: local
  os: macos
  arch: arm64
  ruby_build_tag: 3.4.7
metadata:
  benchmark_config_path: config/benchmarks/short.yml
  environment_config_path: config/environments/ci-ruby-3.4.yml
  tags:
  - local
  - macos
  - arm64
  - ruby-3.4
[...]
```

## Impact

This fix ensures:
1. Benchmark results are properly serialized in all execution contexts
2. ResultSet aggregation works correctly
3. No more cryptic nil errors
4. Complete benchmark data flows through the entire pipeline

## Lessons Learned

1. Always check for gem interference with global constants
2. The Syck gem is a known source of YAML constant conflicts
3. Test in the same execution context as production (LocalRunner vs DockerRunner behavior differs)
4. Even with proper model definitions, external factors can break serialization
