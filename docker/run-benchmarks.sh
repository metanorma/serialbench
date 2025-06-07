#!/bin/bash

# Serialbench Docker Multi-Ruby Version Benchmark Runner
# Runs comprehensive benchmarks across multiple Ruby versions using Docker

set -e

# Configuration
RUBY_VERSIONS=("3.0" "3.1" "3.2" "3.3" "3.4")
OUTPUT_DIR="docker-results"
CONFIG_FILE="config/full.yml"
DOCKERFILE="docker/Dockerfile.benchmark"
FORCE_REBUILD=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Run comprehensive benchmarks across multiple Ruby versions using Docker"
    echo
    echo "OPTIONS:"
    echo "  --force-rebuild, -f    Force rebuild of Docker images even if they exist"
    echo "  --help, -h             Show this help message"
    echo
    echo "EXAMPLES:"
    echo "  $0                     Run benchmarks (skip building existing images)"
    echo "  $0 --force-rebuild     Run benchmarks and rebuild all images"
    echo "  $0 -f                  Same as --force-rebuild"
    echo
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force-rebuild|-f)
                FORCE_REBUILD=true
                log_info "Force rebuild enabled - will rebuild all Docker images"
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Check if Docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi

    log_success "Docker is available"
}

# Clean up previous results
cleanup_results() {
    if [ -d "$OUTPUT_DIR" ]; then
        log_info "Cleaning up previous results in $OUTPUT_DIR"
        rm -rf "$OUTPUT_DIR"
    fi
    mkdir -p "$OUTPUT_DIR"
}

# Build Docker image for specific Ruby version
build_image() {
    local ruby_version=$1
    local image_name="serialbench:ruby-${ruby_version}"

    # Check if image already exists (unless force rebuild is enabled)
    if [ "$FORCE_REBUILD" = false ] && docker image inspect "${image_name}" >/dev/null 2>&1; then
        log_success "Image ${image_name} already exists, skipping build"
        return 0
    fi

    if [ "$FORCE_REBUILD" = true ] && docker image inspect "${image_name}" >/dev/null 2>&1; then
        log_info "Force rebuild enabled, removing existing image ${image_name}..."
        docker rmi "${image_name}" >/dev/null 2>&1 || true
    fi

    log_info "Building Docker image for Ruby ${ruby_version}..."

    if docker build \
        --build-arg RUBY_VERSION="${ruby_version}" \
        -t "${image_name}" \
        -f "${DOCKERFILE}" \
        . > "${OUTPUT_DIR}/build-ruby-${ruby_version}.log" 2>&1; then
        log_success "Built image ${image_name}"
        return 0
    else
        log_error "Failed to build image for Ruby ${ruby_version}"
        log_error "Check ${OUTPUT_DIR}/build-ruby-${ruby_version}.log for details"
        return 1
    fi
}

# Run benchmarks for specific Ruby version
run_benchmark() {
    local ruby_version=$1
    local image_name="serialbench:ruby-${ruby_version}"
    local container_name="serialbench-ruby-${ruby_version}"
    local result_dir="${OUTPUT_DIR}/ruby-${ruby_version}"

    log_info "Running benchmarks for Ruby ${ruby_version}..."

    # Create result directory
    mkdir -p "${result_dir}"

    # Run container with benchmark
    if docker run \
        --name "${container_name}" \
        --rm \
        -v "$(pwd)/${result_dir}:/app/results" \
        "${image_name}" \
        > "${result_dir}/benchmark.log" 2>&1; then
        log_success "Completed benchmarks for Ruby ${ruby_version}"
        return 0
    else
        log_error "Failed to run benchmarks for Ruby ${ruby_version}"
        log_error "Check ${result_dir}/benchmark.log for details"
        return 1
    fi
}

# Merge results from all Ruby versions
merge_results() {
    log_info "Merging results from all Ruby versions..."

    local input_dirs=""
    for version in "${RUBY_VERSIONS[@]}"; do
        local result_dir="${OUTPUT_DIR}/ruby-${version}"
        if [ -d "${result_dir}" ] && [ -f "${result_dir}/data/results.json" ]; then
            input_dirs="${input_dirs} ${result_dir}"
        else
            log_warning "No results found for Ruby ${version}"
        fi
    done

    if [ -n "$input_dirs" ]; then
        if bundle exec serialbench merge_results ${input_dirs} "${OUTPUT_DIR}/merged"; then
            log_success "Results merged successfully"
        else
            log_error "Failed to merge results"
            return 1
        fi
    else
        log_error "No valid results to merge"
        return 1
    fi
}

# Generate GitHub Pages
generate_github_pages() {
    log_info "Generating GitHub Pages..."

    local input_dirs=""
    for version in "${RUBY_VERSIONS[@]}"; do
        local result_dir="${OUTPUT_DIR}/ruby-${version}"
        if [ -d "${result_dir}" ] && [ -f "${result_dir}/data/results.json" ]; then
            input_dirs="${input_dirs} ${result_dir}"
        fi
    done

    if [ -n "$input_dirs" ]; then
        if bundle exec serialbench github_pages ${input_dirs} "${OUTPUT_DIR}/docs"; then
            log_success "GitHub Pages generated successfully"
            log_info "Open ${OUTPUT_DIR}/docs/index.html to view results"
        else
            log_error "Failed to generate GitHub Pages"
            return 1
        fi
    else
        log_error "No valid results for GitHub Pages generation"
        return 1
    fi
}

# Build all Docker images (fail fast)
build_all_images() {
    local failed_builds=()

    for version in "${RUBY_VERSIONS[@]}"; do
        if ! build_image "${version}"; then
            failed_builds+=("${version}")
        fi
    done

    if [ ${#failed_builds[@]} -gt 0 ]; then
        log_error "Failed to build images for Ruby versions: ${failed_builds[*]}"
        log_error "Aborting benchmark run due to build failures"
        exit 1
    fi

    log_success "All Docker images built successfully"
}

# Run benchmarks on all built images
run_all_benchmarks() {
    local successful_runs=0
    local failed_runs=()

    for version in "${RUBY_VERSIONS[@]}"; do
        if run_benchmark "${version}"; then
            ((successful_runs++))
        else
            failed_runs+=("${version}")
            log_warning "Benchmark failed for Ruby ${version}"
        fi
    done

    log_info "Benchmark runs completed: ${successful_runs}/${#RUBY_VERSIONS[@]} successful"

    if [ ${#failed_runs[@]} -gt 0 ]; then
        log_warning "Failed benchmark runs for Ruby versions: ${failed_runs[*]}"
    fi

    # Store results for processing phase
    echo "${successful_runs}" > "${OUTPUT_DIR}/.successful_runs"
}

# Process results (fail if no successful runs)
process_results() {
    local successful_runs
    if [ -f "${OUTPUT_DIR}/.successful_runs" ]; then
        successful_runs=$(cat "${OUTPUT_DIR}/.successful_runs")
    else
        successful_runs=0
    fi

    if [ "${successful_runs}" -eq 0 ]; then
        log_error "No successful benchmark runs to process"
        exit 1
    fi

    log_info "Processing ${successful_runs} successful benchmark results..."

    if ! merge_results; then
        log_error "Failed to merge results"
        exit 1
    fi

    if ! generate_github_pages; then
        log_error "Failed to generate GitHub Pages"
        exit 1
    fi

    log_success "Results processed successfully"
}

# Print summary
print_summary() {
    echo
    echo "=========================================="
    echo "Serialbench Docker Benchmark Summary"
    echo "=========================================="
    echo

    for version in "${RUBY_VERSIONS[@]}"; do
        local result_dir="${OUTPUT_DIR}/ruby-${version}"
        if [ -f "${result_dir}/data/results.json" ]; then
            echo "✅ Ruby ${version}: Completed"
        else
            echo "❌ Ruby ${version}: Failed"
        fi
    done

    echo
    if [ -f "${OUTPUT_DIR}/merged/merged_results.json" ]; then
        echo "📊 Merged results: ${OUTPUT_DIR}/merged/merged_results.json"
    fi

    if [ -f "${OUTPUT_DIR}/docs/index.html" ]; then
        echo "🌐 GitHub Pages: ${OUTPUT_DIR}/docs/index.html"
        echo
        echo "To view results, open: file://$(pwd)/${OUTPUT_DIR}/docs/index.html"
    fi

    echo
}

# Main execution
main() {
    # Parse command line arguments first
    parse_arguments "$@"

    echo "=========================================="
    echo "Serialbench Docker Multi-Ruby Benchmarks"
    echo "=========================================="
    echo

    # Check prerequisites
    check_docker

    # Clean up
    cleanup_results

    # Phase 1: Build all images (fail fast)
    echo
    log_info "Phase 1: Building all Docker images..."
    build_all_images

    # Phase 2: Run all benchmarks
    echo
    log_info "Phase 2: Running benchmarks on all images..."
    run_all_benchmarks

    # Phase 3: Process results (fail if no successful runs)
    echo
    log_info "Phase 3: Processing results..."
    process_results

    # Print summary
    print_summary

    log_success "Docker benchmark run completed!"
}

# Run main function
main "$@"
