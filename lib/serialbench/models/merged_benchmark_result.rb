# frozen_string_literal: true

require 'yaml'
require 'json'
require 'time'

module Serialbench
  module Models
    class MergedBenchmarkResult
      attr_accessor :environments, :combined_results, :metadata

      def initialize(data = {})
        @environments = {}
        @combined_results = CombinedResults.new(data['combined_results'] || data[:combined_results] || {})
        @metadata = Metadata.new(data['metadata'] || data[:metadata] || {})

        # Initialize environments
        env_data = data['environments'] || data[:environments] || {}
        env_data.each do |env_id, env_info|
          @environments[env_id] = EnvironmentInfo.new(env_info)
        end
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
          'environments' => environments_to_hash,
          'combined_results' => @combined_results.to_hash,
          'metadata' => @metadata.to_hash
        }.reject { |_, v| v.nil? || (v.respond_to?(:empty?) && v.empty?) }
      end

      def validate!
        validator = Serialbench::SchemaValidator.new
        validator.validate_merged_benchmark(to_hash)
      end

      def valid?
        validate!
        true
      rescue Serialbench::SchemaValidator::ValidationError
        false
      end

      def add_environment(env_id, env_info)
        @environments[env_id] = env_info.is_a?(EnvironmentInfo) ?
                                env_info :
                                EnvironmentInfo.new(env_info)
      end

      def ruby_versions
        @metadata.ruby_versions
      end

      def platforms
        @metadata.platforms
      end

      private

      def environments_to_hash
        result = {}
        @environments.each do |env_id, env_info|
          result[env_id] = env_info.to_hash
        end
        result
      end
    end

    class EnvironmentInfo
      attr_accessor :ruby_version, :ruby_platform, :source_file, :timestamp, :environment

      def initialize(data = {})
        @ruby_version = data['ruby_version'] || data[:ruby_version]
        @ruby_platform = data['ruby_platform'] || data[:ruby_platform]
        @source_file = data['source_file'] || data[:source_file]
        @timestamp = data['timestamp'] || data[:timestamp]
        @environment = Environment.new(data['environment'] || data[:environment] || {})
      end

      def to_hash
        {
          'ruby_version' => @ruby_version,
          'ruby_platform' => @ruby_platform,
          'source_file' => @source_file,
          'timestamp' => @timestamp,
          'environment' => @environment.to_hash
        }.reject { |_, v| v.nil? || (v.respond_to?(:empty?) && v.empty?) }
      end
    end

    class CombinedResults
      attr_accessor :parsing, :generation, :memory, :streaming

      def initialize(data = {})
        @parsing = CombinedOperationResults.new(data['parsing'] || data[:parsing] || {})
        @generation = CombinedOperationResults.new(data['generation'] || data[:generation] || {})
        @memory = CombinedMemoryResults.new(data['memory'] || data[:memory] || {})
        @streaming = CombinedOperationResults.new(data['streaming'] || data[:streaming] || {})
      end

      def to_hash
        result = {}
        result['parsing'] = @parsing.to_hash unless @parsing.empty?
        result['generation'] = @generation.to_hash unless @generation.empty?
        result['memory'] = @memory.to_hash unless @memory.empty?
        result['streaming'] = @streaming.to_hash unless @streaming.empty?
        result
      end

      def empty?
        @parsing.empty? && @generation.empty? && @memory.empty? && @streaming.empty?
      end
    end

    class CombinedOperationResults
      attr_accessor :small, :medium, :large

      def initialize(data = {})
        @small = CombinedSizeResults.new(data['small'] || data[:small] || {})
        @medium = CombinedSizeResults.new(data['medium'] || data[:medium] || {})
        @large = CombinedSizeResults.new(data['large'] || data[:large] || {})
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

    class CombinedMemoryResults
      attr_accessor :small, :medium, :large

      def initialize(data = {})
        @small = CombinedMemorySizeResults.new(data['small'] || data[:small] || {})
        @medium = CombinedMemorySizeResults.new(data['medium'] || data[:medium] || {})
        @large = CombinedMemorySizeResults.new(data['large'] || data[:large] || {})
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

    class CombinedSizeResults
      attr_accessor :xml, :json, :yaml, :toml

      def initialize(data = {})
        @xml = CombinedFormatResults.new(data['xml'] || data[:xml] || {})
        @json = CombinedFormatResults.new(data['json'] || data[:json] || {})
        @yaml = CombinedFormatResults.new(data['yaml'] || data[:yaml] || {})
        @toml = CombinedFormatResults.new(data['toml'] || data[:toml] || {})
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

    class CombinedMemorySizeResults
      attr_accessor :xml, :json, :yaml, :toml

      def initialize(data = {})
        @xml = CombinedMemoryFormatResults.new(data['xml'] || data[:xml] || {})
        @json = CombinedMemoryFormatResults.new(data['json'] || data[:json] || {})
        @yaml = CombinedMemoryFormatResults.new(data['yaml'] || data[:yaml] || {})
        @toml = CombinedMemoryFormatResults.new(data['toml'] || data[:toml] || {})
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

    class CombinedFormatResults
      def initialize(data = {})
        @serializers = {}
        data.each do |serializer, env_results|
          @serializers[serializer] = {}
          env_results.each do |env_id, perf_data|
            @serializers[serializer][env_id] = PerformanceData.new(perf_data)
          end
        end
      end

      def [](serializer)
        @serializers[serializer] || {}
      end

      def []=(serializer, env_results)
        @serializers[serializer] = {}
        env_results.each do |env_id, perf_data|
          @serializers[serializer][env_id] = perf_data.is_a?(PerformanceData) ?
                                             perf_data :
                                             PerformanceData.new(perf_data)
        end
      end

      def add_result(serializer, env_id, performance_data)
        @serializers[serializer] ||= {}
        @serializers[serializer][env_id] = performance_data.is_a?(PerformanceData) ?
                                           performance_data :
                                           PerformanceData.new(performance_data)
      end

      def to_hash
        result = {}
        @serializers.each do |serializer, env_results|
          result[serializer] = {}
          env_results.each do |env_id, perf_data|
            result[serializer][env_id] = perf_data.to_hash
          end
        end
        result
      end

      def empty?
        @serializers.empty?
      end

      def serializers
        @serializers.keys
      end

      def environments_for(serializer)
        @serializers[serializer]&.keys || []
      end
    end

    class CombinedMemoryFormatResults
      def initialize(data = {})
        @serializers = {}
        data.each do |serializer, env_results|
          @serializers[serializer] = {}
          env_results.each do |env_id, mem_data|
            @serializers[serializer][env_id] = MemoryData.new(mem_data)
          end
        end
      end

      def [](serializer)
        @serializers[serializer] || {}
      end

      def []=(serializer, env_results)
        @serializers[serializer] = {}
        env_results.each do |env_id, mem_data|
          @serializers[serializer][env_id] = mem_data.is_a?(MemoryData) ?
                                             mem_data :
                                             MemoryData.new(mem_data)
        end
      end

      def add_result(serializer, env_id, memory_data)
        @serializers[serializer] ||= {}
        @serializers[serializer][env_id] = memory_data.is_a?(MemoryData) ?
                                           memory_data :
                                           MemoryData.new(memory_data)
      end

      def to_hash
        result = {}
        @serializers.each do |serializer, env_results|
          result[serializer] = {}
          env_results.each do |env_id, mem_data|
            result[serializer][env_id] = mem_data.to_hash
          end
        end
        result
      end

      def empty?
        @serializers.empty?
      end

      def serializers
        @serializers.keys
      end

      def environments_for(serializer)
        @serializers[serializer]&.keys || []
      end
    end

    class Metadata
      attr_accessor :merged_at, :ruby_versions, :platforms

      def initialize(data = {})
        @merged_at = data['merged_at'] || data[:merged_at] || Time.now.iso8601
        @ruby_versions = data['ruby_versions'] || data[:ruby_versions] || []
        @platforms = data['platforms'] || data[:platforms] || []
      end

      def to_hash
        {
          'merged_at' => @merged_at,
          'ruby_versions' => @ruby_versions,
          'platforms' => @platforms
        }.reject { |_, v| v.nil? || (v.respond_to?(:empty?) && v.empty?) }
      end

      def add_ruby_version(version)
        @ruby_versions << version unless @ruby_versions.include?(version)
        @ruby_versions.sort!
      end

      def add_platform(platform)
        @platforms << platform unless @platforms.include?(platform)
        @platforms.sort!
      end
    end
  end
end
