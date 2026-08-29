# frozen_string_literal: true

require 'thor'
require 'json'
require 'yaml'
require 'fileutils'

module Serialbench
  module Cli
    # Base class for CLI commands with shared functionality
    class BaseCli < Thor
      include Thor::Actions

      def self.exit_on_failure?
        true
      end

      protected

      def load_configuration(config_path)
        unless File.exist?(config_path)
          say "Configuration file not found: #{config_path}", :red
          exit 1
        end

        begin
          config = YAML.load_file(config_path)
          say "Loaded configuration from: #{config_path}", :cyan
          config
        rescue StandardError => e
          say "Error loading configuration: #{e.message}", :red
          exit 1
        end
      end

      def validate_name(name_with_path)
        return if name_with_path.nil? || name_with_path.empty?

        name = File.basename(name_with_path)
        return if name.match?(/\A[a-zA-Z0-9_-]+\z/)

        say "Invalid name '#{name}'. Names can only contain letters, numbers, hyphens, and underscores.", :red
        exit 1
      end

      def generate_timestamp
        Time.now.utc.strftime('%Y%m%d_%H%M%S')
      end

      def load_environment_config(environment_config_path)
        unless File.exist?(environment_config_path)
          say "❌ Environment not found: #{environment_config_path}", :red
          exit 1
        end

        require_relative '../models/environment_config'
        Models::EnvironmentConfig.from_yaml(IO.read(environment_config_path))
      rescue StandardError => e
        say "❌ Failed to load environment config: #{e.message}", :red
        exit 1
      end

      def load_benchmark_config(benchmark_config_path)
        unless File.exist?(benchmark_config_path)
          say "❌ Benchmark configuration file not found: #{benchmark_config_path}", :red
          exit 1
        end

        require_relative '../models/benchmark_config'
        Models::BenchmarkConfig.from_yaml(IO.read(benchmark_config_path))
      rescue StandardError => e
        say "❌ Failed to load benchmark config: #{e.message}", :red
        exit 1
      end
    end
  end
end
