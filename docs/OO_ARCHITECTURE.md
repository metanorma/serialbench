# Object-Oriented Architecture for Serialbench Results

This document describes the new comprehensive object-oriented architecture implemented for managing benchmark results, run sets, and reports.

## Overview

The new architecture provides a clean, extensible system for:
- Managing individual benchmark runs with rich metadata
- Creating and managing run sets (collections of related runs)
- Generating reports from runs or run sets
- Organizing results in a consistent directory structure
- Platform detection and string generation
- Result discovery and filtering

## Core Classes

### 1. Platform (`lib/serialbench/models/platform.rb`)

Encapsulates platform detection and string generation.

**Key Features:**
- Detects current OS, architecture, and Ruby version
- Generates consistent platform strings
- Supports both Docker and local platforms
- Provides platform-specific tags

**Platform String Examples:**
- Docker: `docker-alpine-arm64-ruby-3.3`
- Local: `local-macos-arm64-ruby-3.3.8`

**Usage:**
```ruby
# Create platforms
docker_platform = Platform.docker(ruby_version: "3.3.0", variant: "alpine")
local_platform = Platform.current_local

# Get platform string and tags
docker_platform.platform_string  # => "docker-alpine-arm64-ruby-3.3"
docker_platform.tags            # => ["docker", "arm64", "ruby-3.3", "alpine"]
```

### 2. RunResult (`lib/serialbench/models/run_result.rb`)

Represents a single benchmark run with full metadata and platform information.

**Key Features:**
- Wraps BenchmarkResult with platform and metadata
- Automatic directory structure creation
- Tag-based filtering and discovery
- Validation and error handling

**Directory Structure:**
```
results/runs/{platform-string}/
├── data/
│   ├── results.yaml
│   └── results.json
├── metadata.yaml
├── metadata.json
├── platform.yaml
├── platform.json
├── reports/
├── assets/
└── charts/
```

**Usage:**
```ruby
# Create and save a run
run = RunResult.create("docker-alpine-arm64-ruby-3.3", benchmark_data)
run.save

# Load existing run
run = RunResult.load("results/runs/docker-alpine-arm64-ruby-3.3")

# Find runs by tags
runs = RunResult.find_by_tags(["docker", "ruby-3.3"])
```

### 3. RunSetResult (`lib/serialbench/models/run_set_result.rb`)

Represents aggregated results from multiple runs with automatic merging.

**Key Features:**
- Combines multiple RunResults into a single entity
- Automatic result merging using existing ResultMerger
- Inherited tags from constituent runs
- Timestamped naming with ISO 8601 format

**Directory Structure:**
```
results/sets/{name}-{timestamp}/
├── merged_results.yaml
├── merged_results.json
├── metadata.yaml
├── metadata.json
└── runs/
    └── summary.yaml
```

**Usage:**
```ruby
# Create run set from existing runs
run_set = RunSetResult.create("performance-test", [run1, run2, run3])
run_set.save

# Load existing run set
run_set = RunSetResult.load("results/sets/performance-test-2025-06-10T071840Z")

# Add/remove runs
run_set.add_run(new_run)
run_set.remove_run("docker-alpine-arm64-ruby-3.3")
```

### 4. Report (`lib/serialbench/models/report.rb`)

Generates HTML reports from either RunResult or RunSetResult.

**Key Features:**
- Auto-detects input type (single run vs run set)
- Uses existing template system
- Copies assets and creates complete sites
- Supports custom output paths and template types

**Usage:**
```ruby
# Generate report from run
Report.generate(run, "_site/")

# Generate report from run set
Report.generate(run_set, "_site/")

# Generate from path (auto-detects type)
Report.generate("results/runs/docker-alpine-arm64-ruby-3.3", "_site/")
```

### 5. ResultStore (`lib/serialbench/models/result_store.rb`)

Manages the results directory structure and provides discovery/management operations.

**Key Features:**
- Centralized directory management
- Run and run set discovery with filtering
- Statistics and cleanup operations
- Migration from old directory structures
- Validation and repair capabilities

**Usage:**
```ruby
store = ResultStore.default

# Find runs and run sets
recent_runs = store.latest_runs(5)
docker_runs = store.find_runs(tags: ["docker"])
run_sets = store.find_run_sets(limit: 10)

# Statistics
stats = store.stats
# => {
#   "total_runs" => 15,
#   "total_run_sets" => 3,
#   "ruby_versions" => ["3.1", "3.2", "3.3"],
#   "platforms" => ["docker", "local"],
#   "disk_usage" => 45.67
# }

# Cleanup
store.cleanup_old_runs(30)  # Remove runs older than 30 days
```

### 6. RunSetManager (`lib/serialbench/models/run_set_manager.rb`)

High-level management of run sets with advanced operations.

**Key Features:**
- Bulk operations for creating run sets
- Cross-platform and Ruby version comparisons
- Performance and memory analysis
- Run set validation and repair
- Advanced filtering and discovery

**Usage:**
```ruby
manager = RunSetManager.default

# Create specialized run sets
cross_platform = manager.create_cross_platform_comparison(
  "cross-platform-ruby-3.3",
  ruby_versions: ["3.3"]
)

version_comparison = manager.create_ruby_version_comparison(
  "ruby-versions-docker",
  platforms: ["docker"]
)

# Analysis
analysis = manager.analyze_run_set(run_set)
comparison = manager.compare_run_sets(set1, set2)
```

## Directory Structure

The new architecture organizes all results under a consistent structure:

```
results/
├── runs/                           # Individual benchmark runs
│   ├── docker-alpine-arm64-ruby-3.3/
│   ├── docker-slim-x86_64-ruby-3.2/
│   ├── local-macos-arm64-ruby-3.3.8/
│   └── local-ubuntu-x86_64-ruby-3.1.7/
└── sets/                           # Run sets (collections)
    ├── performance-test-2025-06-10T071840Z/
    ├── cross-platform-2025-06-10T072000Z/
    └── ruby-versions-2025-06-10T072130Z/
```

## Integration with Existing Code

The new architecture is designed to work alongside existing code:

1. **Backward Compatibility**: Existing BenchmarkResult and MergedBenchmarkResult classes are unchanged
2. **Template System**: Reports use the existing TemplateRenderer and templates
3. **Result Merger**: RunSetResult uses the existing ResultMerger for combining results
4. **Schema Validation**: All results continue to use existing schema validation

## Usage Examples

### Complete Workflow

```ruby
# 1. Create a run from benchmark data
platform_string = "docker-alpine-arm64-ruby-3.3"
run = Serialbench::Models.create_run(platform_string, benchmark_data,
  metadata: { benchmark_config: "config/full.yml" })

# 2. Save the run
store = Serialbench::Models.result_store
store.save_run(run)

# 3. Create a run set from multiple runs
run_set = store.create_run_set("performance-comparison", [
  "docker-alpine-arm64-ruby-3.3",
  "local-macos-arm64-ruby-3.3.8"
])

# 4. Generate reports
Serialbench::Models.generate_report(run, "single-run-site/")
Serialbench::Models.generate_report(run_set, "comparison-site/")

# 5. Discovery and analysis
recent_runs = store.latest_runs(5)
docker_runs = store.find_runs(tags: ["docker", "ruby-3.3"])
stats = store.stats
```

### CLI Integration

The architecture is designed to integrate with CLI commands:

```bash
# Runs automatically go to results/runs/
serialbench streambench execute docker --config=config.yml

# Create run sets
serialbench runset create "performance-test" results/runs/docker-*
serialbench runset create "cross-platform" results/runs/docker-alpine-* results/runs/local-*

# Generate sites
serialbench site generate results/runs/docker-alpine-arm64-ruby-3.3
serialbench site generate results/sets/performance-test-2025-06-10T071840Z

# Discovery
serialbench runs list
serialbench runsets list
serialbench runs list --tags docker,ruby-3.3
```

## Benefits

1. **Consistent Structure**: Always know where results are stored
2. **Rich Metadata**: Full traceability with timestamps, tags, and platform info
3. **Flexible Aggregation**: Combine any runs into meaningful sets
4. **Type Safety**: Proper OO design with clear responsibilities
5. **Extensibility**: Easy to add new report types, metadata, or analysis
6. **Discovery**: Powerful filtering and search capabilities
7. **Maintenance**: Cleanup, validation, and repair operations
8. **Migration**: Tools to migrate from old directory structures

## Future Enhancements

The architecture is designed to support future enhancements:

- **Database Backend**: Could be extended to use a database instead of filesystem
- **Remote Storage**: Support for cloud storage backends
- **Advanced Analytics**: More sophisticated performance analysis
- **Caching**: Result caching for faster report generation
- **API**: REST API for programmatic access
- **Web Interface**: Web-based management interface
