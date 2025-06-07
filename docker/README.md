# Serialbench Docker Setup

This directory contains Docker infrastructure for running Serialbench across multiple Ruby versions in isolated environments.

## Files

- `Dockerfile.benchmark` - Multi-stage Dockerfile for building benchmark environments
- `run-benchmarks.sh` - Automated script for running benchmarks across multiple Ruby versions

## Quick Start

### Prerequisites

- Docker installed and running
- Bash shell (Linux/macOS/WSL)

### Running Multi-Ruby Benchmarks

```bash
# From the project root directory
./docker/run-benchmarks.sh
```

This will:
1. Build Docker images for Ruby 3.1, 3.2, 3.3, and 3.4
2. Run comprehensive benchmarks in each environment
3. Merge results from all Ruby versions
4. Generate GitHub Pages with comparative results

### Results

Results are saved in `docker-results/`:
```
docker-results/
├── ruby-3.1/           # Ruby 3.1 results
├── ruby-3.2/           # Ruby 3.2 results
├── ruby-3.3/           # Ruby 3.3 results
├── ruby-3.4/           # Ruby 3.4 results
├── merged/             # Merged results from all versions
└── docs/               # GitHub Pages site
```

## Manual Docker Usage

### Build Image for Specific Ruby Version

```bash
docker build \
  --build-arg RUBY_VERSION=3.3 \
  -t serialbench:ruby-3.3 \
  -f docker/Dockerfile.benchmark \
  .
```

### Run Benchmarks

```bash
# Create results directory
mkdir -p results

# Run benchmarks
docker run \
  --rm \
  -v $(pwd)/results:/app/results \
  serialbench:ruby-3.3
```

### Custom Configuration

```bash
# Use custom config file
docker run \
  --rm \
  -v $(pwd)/results:/app/results \
  -v $(pwd)/config:/app/config \
  serialbench:ruby-3.3 \
  bundle exec serialbench benchmark --config config/ci.yml
```

## Supported Ruby Versions

- Ruby 3.1
- Ruby 3.2
- Ruby 3.3
- Ruby 3.4

## Environment Variables

The Docker images support these environment variables:

- `BUNDLE_PATH` - Bundle installation path
- `BUNDLE_BIN` - Bundle binary path
- `PATH` - System PATH including bundle binaries

## Troubleshooting

### Build Failures

Check build logs in `docker-results/build-ruby-X.X.log`:

```bash
cat docker-results/build-ruby-3.3.log
```

### Runtime Failures

Check benchmark logs in `docker-results/ruby-X.X/benchmark.log`:

```bash
cat docker-results/ruby-3.3/benchmark.log
```

### Docker Issues

Ensure Docker is running:
```bash
docker info
```

Clean up Docker resources:
```bash
# Remove all serialbench images
docker rmi $(docker images serialbench -q)

# Remove all containers
docker container prune
```

## Customization

### Adding Ruby Versions

Edit `RUBY_VERSIONS` array in `run-benchmarks.sh`:

```bash
RUBY_VERSIONS=("3.1" "3.2" "3.3" "3.4" "head")
```

### Custom Benchmark Configuration

Create custom config files in `config/` directory and reference them:

```bash
# In run-benchmarks.sh
CONFIG_FILE="config/custom.yml"
```

### Output Directory

Change the output directory:

```bash
# In run-benchmarks.sh
OUTPUT_DIR="my-results"
```

## Integration with CI/CD

The Docker setup integrates with GitHub Actions. See `.github/workflows/benchmark.yml` for automated benchmark runs.

### GitHub Actions Usage

```yaml
- name: Run Docker Benchmarks
  run: ./docker/run-benchmarks.sh

- name: Upload Results
  uses: actions/upload-artifact@v3
  with:
    name: benchmark-results
    path: docker-results/
```

## Performance Considerations

- Each Ruby version runs in isolation
- Results are automatically merged for comparison
- Memory profiling is enabled by default
- Build caching optimizes subsequent runs

## Security

- Containers run with minimal privileges
- No network access required during benchmarks
- Results are written to mounted volumes only
