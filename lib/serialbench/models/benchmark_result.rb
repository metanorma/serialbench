# frozen_string_literal: true

require 'yaml'
require 'json'
require 'time'

module Serialbench
  module Models
    class BenchmarkResult
      attr_accessor :environment, :parsing, :generation, :memory, :streaming,
                    :ruby_version, :ruby_platform, :timestamp

      def initialize(data = {})
        @environment = Environment.new(data['environment'] || data[:environment] || {})
        @parsing = OperationResults.new(data['parsing'] || data[:parsing] || {})
        @generation = OperationResults.new(data['generation'] || data[:generation] || {})
        @memory = MemoryResults.new(data['memory'] || data[:memory] || {})
        @streaming = OperationResults.new(data['streaming'] || data[:streaming] || {})
        @ruby_version = data['ruby_version'] || data[:ruby_version]
        @ruby_platform = data['ruby_platform'] || data[:ruby_platform]
        @timestamp = data['timestamp'] || data[:timestamp] || Time.now.iso8601
      end

      def self.from_file(file_path)
        case File.extname(file_path).downcase
        when '.yaml', '.yml'
          from_yaml_file(file_path)
        when '.json'
          from_json_file(file_path)
        else
          raise ArgumentError, "Unsupported file format: #{File.extname(file_path)}"
        end
      end

      def self.from_yaml_file(file_path)
        data = YAML.load_file(file_path)
        new(data)
      end

      def self.from_json_file(file_path)
        data = JSON.parse(File.read(file_path))
        new(data)
      end

      def to_yaml_file(file_path)
        File.write(file_path, to_yaml)
      end

      def to_json_file(file_path)
        File.write(file_path, to_json)
      end

      def to_yaml
        to_hash.to_yaml
      end

      def to_json
        JSON.pretty_generate(to_hash)
      end

      def to_hash
        {
          'environment' => @environment.to_hash,
          'parsing' => @parsing.to_hash,
          'generation' => @generation.to_hash,
          'memory' => @memory.to_hash,
          'streaming' => @streaming.to_hash,
          'ruby_version' => @ruby_version,
          'ruby_platform' => @ruby_platform,
          'timestamp' => @timestamp
        }.reject { |_, v| v.nil? || (v.respond_to?(:empty?) && v.empty?) }
      end

      def validate!
        validator = Serialbench::SchemaValidator.new
        validator.validate_single_benchmark(to_hash)
      end

      def valid?
        validate!
        true
      rescue Serialbench::SchemaValidator::ValidationError
        false
      end
    end

    class Environment
      attr_accessor :ruby_version, :ruby_platform, :serializer_versions, :timestamp

      def initialize(data = {})
        @ruby_version = data['ruby_version'] || data[:ruby_version]
        @ruby_platform = data['ruby_platform'] || data[:ruby_platform]
        @serializer_versions = data['serializer_versions'] || data[:serializer_versions] || {}
        @timestamp = data['timestamp'] || data[:timestamp] || Time.now.iso8601
      end

      def to_hash
        {
          'ruby_version' => @ruby_version,
          'ruby_platform' => @ruby_platform,
          'serializer_versions' => @serializer_versions,
          'timestamp' => @timestamp
        }.reject { |_, v| v.nil? }
      end
    end

    class OperationResults
      attr_accessor :small, :medium, :large

      def initialize(data = {})
        @small = SizeResults.new(data['small'] || data[:small] || {})
        @medium = SizeResults.new(data['medium'] || data[:medium] || {})
        @large = SizeResults.new(data['large'] || data[:large] || {})
      end

      def to_hash
        result = {}
        result['small'] = @small.to_hash unless @small.empty?
        result['medium'] = @medium.to_hash unless @medium.empty?
        result['large'] = @large.to_hash unless @large.empty?
        result
      end

      def empty?
        @small.empty? && @medium.empty? && @large.empty?
      end
    end

    class MemoryResults
      attr_accessor :small, :medium, :large

      def initialize(data = {})
        @small = MemorySizeResults.new(data['small'] || data[:small] || {})
        @medium = MemorySizeResults.new(data['medium'] || data[:medium] || {})
        @large = MemorySizeResults.new(data['large'] || data[:large] || {})
      end

      def to_hash
        result = {}
        result['small'] = @small.to_hash unless @small.empty?
        result['medium'] = @medium.to_hash unless @medium.empty?
        result['large'] = @large.to_hash unless @large.empty?
        result
      end

      def empty?
        @small.empty? && @medium.empty? && @large.empty?
      end
    end

    class SizeResults
      attr_accessor :xml, :json, :yaml, :toml

      def initialize(data = {})
        @xml = FormatResults.new(data['xml'] || data[:xml] || {})
        @json = FormatResults.new(data['json'] || data[:json] || {})
        @yaml = FormatResults.new(data['yaml'] || data[:yaml] || {})
        @toml = FormatResults.new(data['toml'] || data[:toml] || {})
      end

      def to_hash
        result = {}
        result['xml'] = @xml.to_hash unless @xml.empty?
        result['json'] = @json.to_hash unless @json.empty?
        result['yaml'] = @yaml.to_hash unless @yaml.empty?
        result['toml'] = @toml.to_hash unless @toml.empty?
        result
      end

      def empty?
        @xml.empty? && @json.empty? && @yaml.empty? && @toml.empty?
      end
    end

    class MemorySizeResults
      attr_accessor :xml, :json, :yaml, :toml

      def initialize(data = {})
        @xml = MemoryFormatResults.new(data['xml'] || data[:xml] || {})
        @json = MemoryFormatResults.new(data['json'] || data[:json] || {})
        @yaml = MemoryFormatResults.new(data['yaml'] || data[:yaml] || {})
        @toml = MemoryFormatResults.new(data['toml'] || data[:toml] || {})
      end

      def to_hash
        result = {}
        result['xml'] = @xml.to_hash unless @xml.empty?
        result['json'] = @json.to_hash unless @json.empty?
        result['yaml'] = @yaml.to_hash unless @yaml.empty?
        result['toml'] = @toml.to_hash unless @toml.empty?
        result
      end

      def empty?
        @xml.empty? && @json.empty? && @yaml.empty? && @toml.empty?
      end
    end

    class FormatResults
      def initialize(data = {})
        @serializers = {}
        data.each do |serializer, perf_data|
          @serializers[serializer] = PerformanceData.new(perf_data)
        end
      end

      def [](serializer)
        @serializers[serializer]
      end

      def []=(serializer, performance_data)
        @serializers[serializer] = performance_data.is_a?(PerformanceData) ?
                                   performance_data :
                                   PerformanceData.new(performance_data)
      end

      def to_hash
        result = {}
        @serializers.each do |serializer, perf_data|
          result[serializer] = perf_data.to_hash
        end
        result
      end

      def empty?
        @serializers.empty?
      end

      def serializers
        @serializers.keys
      end
    end

    class MemoryFormatResults
      def initialize(data = {})
        @serializers = {}
        data.each do |serializer, mem_data|
          @serializers[serializer] = MemoryData.new(mem_data)
        end
      end

      def [](serializer)
        @serializers[serializer]
      end

      def []=(serializer, memory_data)
        @serializers[serializer] = memory_data.is_a?(MemoryData) ?
                                   memory_data :
                                   MemoryData.new(memory_data)
      end

      def to_hash
        result = {}
        @serializers.each do |serializer, mem_data|
          result[serializer] = mem_data.to_hash
        end
        result
      end

      def empty?
        @serializers.empty?
      end

      def serializers
        @serializers.keys
      end
    end

    class PerformanceData
      attr_accessor :time_per_iterations, :time_per_iteration,
                    :iterations_per_second, :iterations_count

      def initialize(data = {})
        @time_per_iterations = data['time_per_iterations'] || data[:time_per_iterations]
        @time_per_iteration = data['time_per_iteration'] || data[:time_per_iteration]
        @iterations_per_second = data['iterations_per_second'] || data[:iterations_per_second]
        @iterations_count = data['iterations_count'] || data[:iterations_count]
      end

      def to_hash
        {
          'time_per_iterations' => @time_per_iterations,
          'time_per_iteration' => @time_per_iteration,
          'iterations_per_second' => @iterations_per_second,
          'iterations_count' => @iterations_count
        }.reject { |_, v| v.nil? }
      end
    end

    class MemoryData
      attr_accessor :total_allocated, :total_retained,
                    :allocated_memory, :retained_memory

      def initialize(data = {})
        @total_allocated = data['total_allocated'] || data[:total_allocated]
        @total_retained = data['total_retained'] || data[:total_retained]
        @allocated_memory = data['allocated_memory'] || data[:allocated_memory]
        @retained_memory = data['retained_memory'] || data[:retained_memory]
      end

      def to_hash
        {
          'total_allocated' => @total_allocated,
          'total_retained' => @total_retained,
          'allocated_memory' => @allocated_memory,
          'retained_memory' => @retained_memory
        }.reject { |_, v| v.nil? }
      end
    end
  end
end
