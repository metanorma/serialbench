# Platform Validation Fix

## Problem

GitHub Actions workflow run [18624230866](https://github.com/metanorma/serialbench/actions/runs/18624230866/job/53099708431) failed with the error:

```
Error adding run to resultset: undefined method `platform_string' for nil
```

This occurred when trying to add benchmark results from `artifacts/benchmark-results-macos-latest-ruby-3.2` to the weekly resultset.

## Root Cause

The error occurred in `lib/serialbench/models/result_set.rb` line 56, where the code attempted to access `result.platform.platform_string` to check for duplicate results. When `result.platform` is `nil`, this causes a NoMethodError.

The underlying issue is that some result files were missing the `platform` section in their YAML data, causing `Result.load()` to return a Result object with a nil platform.

## Solution Implemented

Added validation in the `ResultSet#add_result` method to check for required fields before attempting to access their properties:

```ruby
# Validate that the result has required fields
raise ArgumentError, "Result from #{result_path} is missing platform information" if result.platform.nil?
raise ArgumentError, "Result from #{result_path} is missing environment_config" if result.environment_config.nil?
raise ArgumentError, "Result from #{result_path} is missing benchmark_config" if result.benchmark_config.nil?
```

This provides clear, actionable error messages that indicate:
1. Which result file has the problem
2. Which specific field is missing

## Testing

Created comprehensive RSpec tests in `spec/serialbench/models/result_set_spec.rb` that verify:
- Missing platform information raises appropriate error
- Missing environment_config raises appropriate error
- Missing benchmark_config raises appropriate error
- Complete results are added successfully

All tests pass.

## Next Steps

While this fix improves error reporting, the underlying issue of why platform data is missing needs investigation:

1. **Investigate Result Generation**: Check why some results are being created without platform data
   - Review `LocalRunner#run_benchmark` in `lib/serialbench/runners/local_runner.rb`
   - Review how platform data is serialized in `Platform.to_yaml`
   - Check if there's a Lutaml::Model serialization issue

2. **GitHub Actions Debugging**:
   - Add debugging output to show the contents of result files before adding them to resultsets
   - Verify that all benchmark runs are creating complete result files with platform data

3. **Platform Serialization**: Ensure `Platform` model properly serializes/deserializes:
   - All attributes are included in YAML output
   - Default values are properly set
   - No Lutaml::Model configuration issues

## Commit

```
fix(resultset): add validation for missing platform data in results

Previously, when adding a result to a resultset, if the result's YAML file
was missing platform information (or environment_config/benchmark_config),
the code would fail with 'undefined method platform_string for nil' when
trying to check for duplicates.

This commit adds proper validation to check for nil values before accessing
their properties, providing clear error messages that indicate which field
is missing and which result path has the issue.

Also adds comprehensive RSpec tests to verify the validation works correctly
for all three required fields: platform, environment_config, and benchmark_config.

Fixes the error seen in GitHub Actions workflow run 18624230866.
