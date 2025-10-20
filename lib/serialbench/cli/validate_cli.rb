# frozen_string_literal: true

require_relative 'base_cli'
require_relative '../yaml_validator'

module Serialbench
  module Cli
    # CLI for validating YAML files against schemas
    class ValidateCli < BaseCli
      desc 'result RESULT_FILE', 'Validate a benchmark result YAML file'
      long_desc <<~DESC
        Validate a benchmark result YAML file against its schema.

        RESULT_FILE should be the path to a results.yaml file

        Examples:
          serialbench validate result results/runs/my-run/results.yaml
          serialbench validate result test-artifacts/benchmark-results-ubuntu-latest-ruby-3.4/results.yaml
      DESC
      def result(file_path)
        validate_file(file_path, 'result', 'Result')
      end

      desc 'config BENCHMARK_CONFIG', 'Validate a benchmark configuration file'
      long_desc <<~DESC
        Validate a benchmark configuration file against its schema.

        BENCHMARK_CONFIG should be the path to a benchmark config YAML file

        Examples:
          serialbench validate config config/benchmarks/short.yml
          serialbench validate config config/benchmarks/full.yml
      DESC
      def config(file_path)
        validate_file(file_path, 'benchmark_config', 'Benchmark config')
      end

      desc 'environment ENV_CONFIG', 'Validate an environment configuration file'
      long_desc <<~DESC
        Validate an environment configuration file against its schema.

        ENV_CONFIG should be the path to an environment config YAML file

        Examples:
          serialbench validate environment config/environments/local-dev.yml
          serialbench validate environment config/environments/docker-ruby-3.4.yml
      DESC
      def environment(file_path)
        validate_file(file_path, 'environment_config', 'Environment config')
      end

      desc 'resultset RESULTSET_FILE', 'Validate a resultset YAML file'
      long_desc <<~DESC
        Validate a resultset YAML file against its schema.

        RESULTSET_FILE should be the path to a resultset.yaml file

        Examples:
          serialbench validate resultset results/sets/weekly-benchmark/resultset.yaml
          serialbench validate resultset results/sets/comparison/resultset.yaml
      DESC
      def resultset(file_path)
        validate_file(file_path, 'resultset', 'Resultset')
      end

      private

      def validate_file(file_path, schema_name, friendly_name)
        unless File.exist?(file_path)
          say "❌ File not found: #{file_path}", :red
          exit 1
        end

        say "📝 Validating #{friendly_name}: #{file_path}", :cyan

        if Serialbench::YamlValidator.validate(file_path, schema_name)
          say "✅ #{friendly_name} is valid", :green
        else
          say "❌ #{friendly_name} validation failed", :red
          exit 1
        end
      rescue StandardError => e
        say "❌ Error: #{e.message}", :red
        exit 1
      end
    end
  end
end
