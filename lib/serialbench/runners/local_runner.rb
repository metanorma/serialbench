# frozen_string_literal: true

require 'fileutils'
require_relative 'base'
require_relative '../benchmark_runner'
require_relative '../models/result'
require_relative '../models/platform'

module Serialbench
  module Runners
    # Handles local benchmark execution using the current Ruby environment
    class LocalRunner < Base
      def prepare
        # For local environments, no preparation is needed
        # The current Ruby environment is already set up
        puts "✅ Local environment ready (using current Ruby: #{RUBY_VERSION})"
      end

      def run_benchmark(benchmark_config, benchmark_config_path, result_dir)
        puts "🏠 Running benchmark locally with Ruby #{RUBY_VERSION}..."
        puts "   📁 Results will be saved to: #{result_dir}"

        FileUtils.mkdir_p(result_dir)

        # Run the benchmark
        runner = Serialbench::BenchmarkRunner.new(
          environment_config: @environment_config,
          benchmark_config: benchmark_config
        )

        results = runner.run_all_benchmarks

        # Get platform information with correct Ruby version from environment config
        platform = Serialbench::Models::Platform.current_local(
          ruby_version: @environment_config.ruby_build_tag
        )

        # Create metadata
        metadata = Models::RunMetadata.new(
          benchmark_config_path: benchmark_config_path,
          environment_config_path: @environment_config_path,
          tags: [
            'local',
            platform.os,
            platform.arch,
            "ruby-#{@environment_config.ruby_build_tag}"
          ]
        )

        # Save results
        results_model = Models::Result.new(
          platform: platform,
          metadata: metadata,
          environment_config: @environment_config,
          benchmark_config: benchmark_config,
          benchmark_result: results
        )

        # Restore YAML to use Psych for output, otherwise lutaml-model's to_yaml
        # will have no output (Syck gem overrides YAML constant)
        Object.const_set(:YAML, Psych)

        results_file = File.join(result_dir, 'results.yaml')
        results_model.to_file(results_file)

        puts "✅ Benchmark completed successfully"
        puts "   📊 Results saved to: #{results_file}"
      end
    end
  end
end
