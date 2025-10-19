# frozen_string_literal: true

require 'time'
require 'fileutils'
require_relative 'platform'
require_relative 'benchmark_result'
require_relative 'benchmark_config'
require_relative 'environment_config'

module Serialbench
  module Models
    class RunMetadata < Lutaml::Model::Serializable
      attribute :created_at, :string, default: -> { Time.now.utc.iso8601 }
      attribute :benchmark_config_path, :string
      attribute :environment_config_path, :string
      attribute :tags, :string, collection: true
    end

    class Result < Lutaml::Model::Serializable
      attribute :platform, Platform
      attribute :metadata, RunMetadata
      attribute :environment_config, EnvironmentConfig
      attribute :benchmark_config, BenchmarkConfig
      attribute :benchmark_result, BenchmarkResult

      def self.load(path)
        raise ArgumentError, "Path does not exist: #{path}" unless Dir.exist?(path)

        # Load benchmark data
        data_file = File.join(path, 'results.yaml')

        raise ArgumentError, "No results data found in #{path}" unless File.exist?(data_file)

        yaml_content = IO.read(data_file)

        # Debug: Check if yaml_content is empty or too small
        if yaml_content.nil? || yaml_content.strip.empty?
          raise ArgumentError, "Results file at #{data_file} is empty"
        end

        if yaml_content.bytesize < 200
          warn "WARNING: Results file at #{data_file} is suspiciously small (#{yaml_content.bytesize} bytes)"
          warn "Content preview: #{yaml_content[0..100]}"
        end

        from_yaml(yaml_content)
      end

      def self.find_all(base_path = 'results/runs')
        return [] unless Dir.exist?(base_path)

        Dir.glob(File.join(base_path, '*')).select { |path| Dir.exist?(path) }.map do |path|
          load(path)
        rescue StandardError => e
          warn "Failed to load run result from #{path}: #{e.message}"
          nil
        end.compact
      end

      def to_file(path)
        File.write(path, to_yaml)
      end
    end
  end
end
