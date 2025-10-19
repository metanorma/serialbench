# frozen_string_literal: true

require 'yaml'
require 'time'
require 'fileutils'

module Serialbench
  module Models
    # ResultSet model for managing collections of benchmark results
    class ResultSet < Lutaml::Model::Serializable
      attribute :name, :string
      attribute :description, :string
      attribute :created_at, :string, default: -> { Time.now.utc.iso8601 }
      attribute :updated_at, :string, default: -> { Time.now.utc.iso8601 }
      attribute :results, Result, collection: true, initialize_empty: true

      def self.load(path)
        raise ArgumentError, "Path does not exist: #{path}" unless Dir.exist?(path)

        # Load benchmark data
        data_file = File.join(path, 'resultset.yaml')

        raise ArgumentError, "No results data found in #{path}" unless File.exist?(data_file)

        from_yaml(IO.read(data_file))
      end

      def to_file(path)
        File.write(path, to_yaml)
      end

      def save(dir)
        FileUtils.mkdir_p(dir)
        to_file(File.join(dir, 'resultset.yaml'))
      end

      def add_result(result_path)
        # Assume result_path is the directory containing benchmark results and is named
        # accordingly
        result_name = File.basename(result_path)
        raise ArgumentError, 'Result name cannot be empty' if result_name.empty?
        # Validate that the result path is a directory
        raise ArgumentError, 'Result path must be a directory' unless File.directory?(result_path)

        result_file_path = File.join(result_path, 'results.yaml')
        raise ArgumentError, "No results data found in #{result_path}" unless File.exist?(result_file_path)

        result = Result.load(result_path)

        # Validate that the result has required fields
        raise ArgumentError, "Result from #{result_path} is missing platform information" if result.platform.nil?
        raise ArgumentError, "Result from #{result_path} is missing environment_config" if result.environment_config.nil?
        raise ArgumentError, "Result from #{result_path} is missing benchmark_config" if result.benchmark_config.nil?

        # Check if result already exists:
        # If environment_config.created_at is identical;
        # If platform.platform_string is identical;
        # If benchmark_config.benchmark_name is identical;

        duplicates = results.select do |r|
          r.platform.platform_string == result.platform.platform_string &&
            r.environment_config.created_at == result.environment_config.created_at &&
            r.benchmark_config.benchmark_name == result.benchmark_config.benchmark_name
        end

        raise ArgumentError, 'Result is already present in this resultset' if duplicates.any?

        # Add the result to the resultset
        results << result
        self.updated_at = Time.now.utc.iso8601

        result
      end
    end
  end
end
