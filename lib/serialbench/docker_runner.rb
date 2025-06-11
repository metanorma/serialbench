# frozen_string_literal: true

require 'fileutils'
require 'json'

module Serialbench
  # Handles Docker-based benchmark execution
  class DockerRunner
    class DockerError < StandardError; end

    def initialize(config)
      @config = config
      @output_dir = config.output_dir
      validate_docker_available
    end

    # Prepare Docker images for all Ruby versions and variants
    def prepare
      puts "🐳 Preparing Docker images..."
      cleanup_output_dir

      successful_builds = 0
      total_builds = @config.ruby_versions.size * @config.image_variants.size

      @config.ruby_versions.each do |ruby_version|
        @config.image_variants.each do |variant|
          if build_image(ruby_version, variant)
            successful_builds += 1
          end
        end
      end

      puts "✅ Built #{successful_builds}/#{total_builds} Docker images successfully"

      if successful_builds == 0
        raise DockerError, "Failed to build any Docker images"
      end
    end

    # Run benchmarks on all prepared images
    def benchmark
      puts "🚀 Running benchmarks..."

      successful_runs = 0
      failed_runs = []

      @config.ruby_versions.each do |ruby_version|
        @config.image_variants.each do |variant|
          if run_benchmark(ruby_version, variant)
            successful_runs += 1
          else
            failed_runs << "#{ruby_version}-#{variant}"
          end
        end
      end

      puts "✅ Completed #{successful_runs} benchmark runs"

      if failed_runs.any?
        puts "⚠️  Failed runs: #{failed_runs.join(', ')}"
      end

      if successful_runs == 0
        raise DockerError, "No successful benchmark runs"
      end

      # Process results
      process_results(successful_runs)
    end

    private

    # Validate Docker is available
    def validate_docker_available
      unless system('docker --version > /dev/null 2>&1')
        raise DockerError, "Docker is not installed or not available in PATH"
      end

      unless system('docker info > /dev/null 2>&1')
        raise DockerError, "Docker daemon is not running"
      end
    end

    # Clean up output directory
    def cleanup_output_dir
      if Dir.exist?(@output_dir)
        puts "🧹 Cleaning up previous results in #{@output_dir}"
        FileUtils.rm_rf(@output_dir)
      end
      FileUtils.mkdir_p(@output_dir)
    end

    # Build Docker image for specific Ruby version and variant
    def build_image(ruby_version, variant)
      image_name = "serialbench:ruby-#{ruby_version}-#{variant}"
      dockerfile = dockerfile_path(variant)

      puts "🔨 Building #{image_name}..."

      build_log = File.join(@output_dir, "build-#{ruby_version}-#{variant}.log")

      cmd = [
        'docker', 'build',
        '--build-arg', "RUBY_VERSION=#{ruby_version}",
        '-t', image_name,
        '-f', dockerfile,
        '.'
      ].join(' ')

      success = system("#{cmd} > #{build_log} 2>&1")

      if success
        puts "✅ Built #{image_name}"
        true
      else
        puts "❌ Failed to build #{image_name} (see #{build_log})"
        false
      end
    end

    # Run benchmark for specific Ruby version and variant
    def run_benchmark(ruby_version, variant)
      image_name = "serialbench:ruby-#{ruby_version}-#{variant}"

      # Generate combined platform string: docker-os-arch-interpreter-version
      platform_string = generate_platform_string('docker', ruby_version, variant)
      result_dir = File.join(@output_dir, platform_string)

      puts "🏃 Running benchmarks for #{ruby_version} (#{variant})..."
      puts "   📁 Results will be saved to: #{result_dir}"
      puts "   🐳 Using Docker image: #{image_name}"

      FileUtils.mkdir_p(result_dir)
      benchmark_log = File.join(result_dir, 'benchmark.log')

      cmd = [
        'docker', 'run', '--rm',
        '-v', "#{File.expand_path(result_dir)}:/app/results",
        image_name,
        'bundle', 'exec', 'serialbench', 'benchmark',
        '--config', @config.benchmark_config
      ].join(' ')

      puts "   🔧 Running command: #{cmd}"
      puts "   📝 Benchmark output will be logged to: #{benchmark_log}"
      puts "   ⏳ This may take several minutes..."

      success = system("#{cmd} > #{benchmark_log} 2>&1")

      if success && File.exist?(File.join(result_dir, 'data', 'results.json'))
        puts "✅ Completed #{ruby_version} (#{variant})"
        puts "   📊 Results saved to: #{File.join(result_dir, 'data', 'results.json')}"
        true
      else
        puts "❌ Failed #{ruby_version} (#{variant}) (see #{benchmark_log})"
        puts "   🔍 Check log file for details: #{benchmark_log}"
        if File.exist?(benchmark_log)
          puts "   📄 Last few lines of log:"
          system("tail -10 #{benchmark_log} | sed 's/^/      /'")
        end
        false
      end
    end

    # Process and merge results
    def process_results(successful_runs)
      puts "📊 Processing #{successful_runs} successful results..."

      # Find all result directories with valid results
      result_dirs = Dir.glob(File.join(@output_dir, 'docker-*')).select do |dir|
        results_runs_dir = File.join(dir, 'results', 'runs')
        Dir.exist?(results_runs_dir) && !Dir.glob(File.join(results_runs_dir, '*')).empty?
      end

      if result_dirs.empty?
        puts '⚠️  No results found for processing, but benchmarks completed successfully!'
        puts "📁 Individual results are available in: #{@output_dir}"
        return
      end

      puts '🎉 Results processed successfully!'
      puts "📁 Results directory: #{@output_dir}"
      puts "📊 Individual benchmark results available in:"
      result_dirs.each do |dir|
        puts "   - #{dir}"
      end
      puts ""
      puts "💡 To create a comparison report, use:"
      puts "   serialbench runset new multi-docker-comparison"
      result_dirs.each do |dir|
        result_name = File.basename(dir)
        puts "   serialbench runset add-result multi-docker-comparison #{result_name}"
      end
      puts "   serialbench runset build-site multi-docker-comparison"
    end

    # Generate combined platform string for directory naming
    # Format: docker-{image_variant}-{arch}-ruby-{version}
    def generate_platform_string(runner_type, ruby_version, variant)
      # Get architecture (simplified)
      arch = case RUBY_PLATFORM
             when /x86_64|amd64/
               'x64'
             when /arm64|aarch64/
               'arm64'
             when /i386|i686/
               'x86'
             else
               'unknown'
             end

      "#{runner_type}-#{variant}-#{arch}-ruby-#{ruby_version}"
    end

    # Get Dockerfile path for variant
    def dockerfile_path(variant)
      case variant
      when 'slim'
        'docker/Dockerfile.benchmark'
      when 'alpine'
        'docker/Dockerfile.alpine'
      else
        raise DockerError, "Unknown Docker variant: #{variant}"
      end
    end
  end
end
