# frozen_string_literal: true

require 'fileutils'
require 'json'
require_relative '../ruby_build_manager'
require_relative 'base'

module Serialbench
  module Runners
    # Handles Docker-based benchmark execution
    class DockerRunner < Base
      class DockerError < StandardError; end

      def initialize(environment_config, environment_config_path)
        super

        @docker_image = @environment_config.docker&.image
        raise 'docker.image is required' unless @docker_image

        # Handle dockerfile path relative to environment file
        dockerfile_path = @environment_config.docker&.dockerfile
        raise 'docker.dockerfile path is required' unless dockerfile_path

        @dockerfile = Pathname.new(environment_config_path).dirname.join(dockerfile_path).to_s
        raise "path '#{@dockerfile}' specified in docker.dockerfile is not found" unless File.exist?(@dockerfile)

        validate_docker_available
      end

      # Build Docker image for this environment
      def prepare
        puts "🐳 Preparing Docker image for #{@name}..."

        puts "   🐍 Using Docker image: #{base_image_string}"
        puts "   🔨 Building Docker image: #{docker_image_string}"

        cmd = [
          'docker', 'build',
          '--build-arg', "BASE_IMAGE=#{base_image_string}",
          '-t', docker_image_string,
          '-f', @dockerfile,
          '.'
        ]

        # Show command being run
        puts "   🔧 Running command: #{cmd.join(' ')}"
        success = system(*cmd)

        raise DockerError, "Failed to build Docker image '#{docker_image_string}'" unless success

        puts "✅ Docker image prepared successfully for #{docker_image_string}"
      end

      def base_image_string
        @environment_config.docker.image
      end

      def docker_image_string
        "serialbench:#{@environment_config.ruby_build_tag}"
      end

      # Run benchmark for this environment
      def run_benchmark(benchmark_config, benchmark_config_path, result_dir)
        puts "🚀 Running benchmark at #{@environment_config_path}..."

        FileUtils.mkdir_p(result_dir)

        # Build image if not already built
        prepare unless image_exists?

        # Run the benchmark
        run_benchmark_in_container(benchmark_config, benchmark_config_path, result_dir)

        puts "✅ Benchmark completed for #{@environment_config_path}"
      end

      private

      # Validate Docker is available
      def validate_docker_available
        unless system('docker --version > /dev/null 2>&1')
          raise DockerError, 'Docker is not installed or not available in PATH'
        end

        return if system('docker info > /dev/null 2>&1')

        raise DockerError, 'Docker daemon is not running'
      end

      # Check if Docker image exists
      def image_exists?
        image_name = "serialbench:#{@name}"
        system("docker image inspect #{image_name} > /dev/null 2>&1")
      end

      # Run benchmark in container
      def run_benchmark_in_container(benchmark_config, benchmark_config_path, result_dir)
        puts '🏃 Running benchmark in Docker container...'
        puts "   📁 Results will be saved to: #{result_dir}"
        puts "   🐳 Using Docker image: #{docker_image_string}"

        benchmark_log = File.join(result_dir, 'benchmark.log')

        cmd = [
          'docker', 'run', '--rm',
          '-v', "#{File.expand_path(result_dir)}:/app/results",
          '-v', "#{File.expand_path(@environment_config_path)}:/app/environment.yml",
          '-v', "#{File.expand_path(benchmark_config_path)}:/app/benchmark_config.yml",
          # TODO: do not hard code this path in the docker image
          '-v', "#{RubyBuildManager::CACHE_FILE}:/root/.serialbench/ruby-build-definitions.yaml",
          docker_image_string,
          'benchmark',
          '_docker_execute',
          '--result_dir=/app/results',
          '/app/environment.yml',
          '/app/benchmark_config.yml'
        ]

        puts "   🔧 Running command: #{cmd.join(' ')}"
        puts "   📝 Benchmark output will be logged to: #{benchmark_log}"
        puts '   ⏳ This may take several minutes...'

        success = system("#{cmd.join(' ')} > #{benchmark_log} 2>&1")
        puts "   ✅ Command executed with status: #{success ? 'success' : 'failure'}"
        puts "   📊 Checking if results saved to: #{File.join(result_dir, 'results.yaml')}"

        if success && File.exist?(File.join(result_dir, 'results.yaml'))
          puts '✅ Benchmark completed successfully'
          puts "   📊 Results saved to: #{File.join(result_dir, 'results.yaml')}"
        else
          puts "❌ Benchmark failed (see #{benchmark_log})"
          puts "   🔍 Check log file for details: #{benchmark_log}"
          if File.exist?(benchmark_log)
            puts '   📄 Last few lines of log:'
            system("tail -10 #{benchmark_log} | sed 's/^/      /'")
          end
          raise DockerError, 'Benchmark execution failed'
        end
      end
    end
  end
end
