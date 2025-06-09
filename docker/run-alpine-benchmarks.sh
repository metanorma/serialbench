#!/bin/bash

# Run benchmarks on Alpine Linux for multiple Ruby versions
set -e

RUBY_VERSIONS=("3.0.7" "3.1.7" "3.2.8" "3.3.8" "3.4.4")
OUTPUT_DIR="alpine-results"

echo "Starting Alpine Linux benchmarks..."
mkdir -p "$OUTPUT_DIR"

for version in "${RUBY_VERSIONS[@]}"; do
    echo "Building Alpine image for Ruby $version..."

    # Build the Alpine image
    docker build \
        --build-arg RUBY_VERSION="$version" \
        -f docker/Dockerfile.alpine \
        -t "serialbench-alpine:ruby-$version" \
        .

    echo "Running benchmarks for Ruby $version on Alpine..."

    # Create output directory for this version
    mkdir -p "$OUTPUT_DIR/ruby-$version"

    # Run the benchmark
    docker run --rm \
        -v "$(pwd)/$OUTPUT_DIR/ruby-$version:/output" \
        "serialbench-alpine:ruby-$version" \
        bash -c "
            eval \"\$(rbenv init -)\" && \
            bundle exec serialbench benchmark --config config/short.yml && \
            cp -r results/* /output/ && \
            echo 'Ruby $version on Alpine completed successfully' > /output/build.log
        "

    echo "✅ Ruby $version on Alpine completed"
done

echo "🎉 All Alpine benchmarks completed!"
echo "Results saved in: $OUTPUT_DIR/"
