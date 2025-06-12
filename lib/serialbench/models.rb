# frozen_string_literal: true

require_relative 'models/benchmark_result'
require_relative 'models/platform'
require_relative 'models/result'
require_relative 'models/result_store'
require_relative 'models/benchmark_config'
require_relative 'models/environment_config'
require_relative 'models/result_set'

module Serialbench
  module Models
    # Factory method to create appropriate model based on data structure
    def self.from_file(file_path)
      case File.extname(file_path).downcase
      when '.yaml', '.yml'
        data = YAML.load_file(file_path)
      when '.json'
        data = JSON.parse(File.read(file_path))
      else
        raise ArgumentError, "Unsupported file format: #{File.extname(file_path)}"
      end

      from_data(data)
    end

    def self.from_data(data)
      BenchmarkResult.new(data)
    end

    # Convert any benchmark result to YAML format
    def self.to_yaml_file(result, file_path)
      result.to_yaml_file(file_path)
    end

    # Convert any benchmark result to JSON format (for HTML templates)
    def self.to_json_file(result, file_path)
      result.to_json_file(file_path)
    end

    # Convenience methods for the new OO architecture
    def self.result_store
      ResultStore.default
    end

    def self.create_run(platform_string, benchmark_data, metadata: {})
      Result.create(platform_string, benchmark_data, metadata: metadata)
    end

    def self.create_resultset(name, run_paths_or_objects, metadata: {})
      ResultSet.create(name, run_paths_or_objects, metadata: metadata)
    end
  end
end
