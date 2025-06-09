# frozen_string_literal: true

require_relative 'models/benchmark_result'
require_relative 'models/merged_benchmark_result'

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
      if data['combined_results'] && data['environments']
        MergedBenchmarkResult.new(data)
      else
        BenchmarkResult.new(data)
      end
    end

    # Convert any benchmark result to YAML format
    def self.to_yaml_file(result, file_path)
      result.to_yaml_file(file_path)
    end

    # Convert any benchmark result to JSON format (for HTML templates)
    def self.to_json_file(result, file_path)
      result.to_json_file(file_path)
    end
  end
end
