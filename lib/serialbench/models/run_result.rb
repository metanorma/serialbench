# frozen_string_literal: true

require 'yaml'
require 'json'
require 'time'
require 'fileutils'
require_relative 'platform'
require_relative 'benchmark_result'

module Serialbench
  module Models
    class RunResult
      attr_reader :platform, :benchmark_result, :metadata, :path

      def initialize(platform:, benchmark_result: nil, metadata: {}, path: nil)
        @platform = platform.is_a?(Platform) ? platform : Platform.new(**platform)
        @benchmark_result = benchmark_result
        @metadata = RunMetadata.new(metadata)
        @path = path
      end

      def self.create(platform_string, benchmark_data, metadata: {})
        platform = parse_platform_string(platform_string)
        benchmark_result = BenchmarkResult.new(benchmark_data)

        new(
          platform: platform,
          benchmark_result: benchmark_result,
          metadata: metadata
        )
      end

      def self.load(path)
        raise ArgumentError, "Path does not exist: #{path}" unless Dir.exist?(path)

        # Load benchmark data
        data_file = File.join(path, 'data', 'results.yaml')
        data_file = File.join(path, 'data', 'results.json') unless File.exist?(data_file)

        raise ArgumentError, "No results data found in #{path}" unless File.exist?(data_file)

        benchmark_result = BenchmarkResult.from_file(data_file)

        # Load metadata
        metadata_file = File.join(path, 'metadata.yaml')
        metadata = File.exist?(metadata_file) ? YAML.load_file(metadata_file) : {}

        # Parse platform from path
        platform_string = File.basename(path)
        platform = parse_platform_string(platform_string)

        new(
          platform: platform,
          benchmark_result: benchmark_result,
          metadata: metadata,
          path: path
        )
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

      def self.find_by_tags(tags, base_path = 'results/runs')
        find_all(base_path).select { |run| (tags - run.tags).empty? }
      end

      def save(base_path = 'results/runs')
        @path = File.join(base_path, @platform.platform_string)

        # Create directory structure
        FileUtils.mkdir_p(File.join(@path, 'data'))
        FileUtils.mkdir_p(File.join(@path, 'reports'))
        FileUtils.mkdir_p(File.join(@path, 'assets'))
        FileUtils.mkdir_p(File.join(@path, 'charts'))

        # Save benchmark data
        @benchmark_result.to_yaml_file(File.join(@path, 'data', 'results.yaml'))
        @benchmark_result.to_json_file(File.join(@path, 'data', 'results.json'))

        # Save metadata
        File.write(File.join(@path, 'metadata.yaml'), @metadata.to_yaml)
        File.write(File.join(@path, 'metadata.json'), @metadata.to_json)

        # Save platform info
        File.write(File.join(@path, 'platform.yaml'), @platform.to_hash.to_yaml)
        File.write(File.join(@path, 'platform.json'), JSON.pretty_generate(@platform.to_hash))

        self
      end

      def tags
        @platform.tags + @metadata.tags
      end

      def ruby_version
        @platform.ruby_version
      end

      def platform_string
        @platform.platform_string
      end

      def created_at
        @metadata.created_at
      end

      def benchmark_config
        @metadata.benchmark_config
      end

      def to_hash
        {
          'platform' => @platform.to_hash,
          'metadata' => @metadata.to_hash,
          'benchmark_result' => @benchmark_result&.to_hash,
          'path' => @path
        }.reject { |_, v| v.nil? }
      end

      def to_yaml
        to_hash.to_yaml
      end

      def to_json(*_args)
        JSON.pretty_generate(to_hash)
      end

      def valid?
        @benchmark_result&.valid? && @metadata.valid?
      end

      def validate!
        @benchmark_result&.validate!
        @metadata.validate!
      end

      private

      def self.parse_platform_string(platform_string)
        parts = platform_string.split('-')

        if parts[0] == 'docker'
          # docker-alpine-arm64-ruby-3.3
          variant = parts[1]
          arch = parts[2]
          ruby_version = parts[4..].join('.')

          Platform.docker(ruby_version: ruby_version, variant: variant)
        elsif parts[0] == 'local'
          # local-macos-arm64-ruby-3.3.8
          os = parts[1]
          arch = parts[2]
          ruby_version = parts[4..].join('.')

          Platform.local(ruby_version: ruby_version)
        elsif parts[0] == 'asdf'
          # asdf-macos-arm64-ruby-3.2.4
          os = parts[1]
          arch = parts[2]
          ruby_version = parts[4..].join('.')

          Platform.local(ruby_version: ruby_version)
        else
          raise ArgumentError, "Invalid platform string format: #{platform_string}"
        end
      end
    end

    class RunMetadata
      attr_accessor :created_at, :benchmark_config, :tags, :name, :description

      def initialize(data = {})
        @created_at = data['created_at'] || data[:created_at] || Time.now.utc.iso8601
        @benchmark_config = data['benchmark_config'] || data[:benchmark_config]
        @tags = Array(data['tags'] || data[:tags])
        @name = data['name'] || data[:name]
        @description = data['description'] || data[:description]
      end

      def to_hash
        {
          'created_at' => @created_at,
          'benchmark_config' => @benchmark_config,
          'tags' => @tags,
          'name' => @name,
          'description' => @description
        }.reject { |_, v| v.nil? || (v.respond_to?(:empty?) && v.empty?) }
      end

      def to_yaml
        to_hash.to_yaml
      end

      def to_json(*_args)
        JSON.pretty_generate(to_hash)
      end

      def valid?
        !@created_at.nil?
      end

      def validate!
        raise ArgumentError, 'created_at is required' if @created_at.nil?
      end

      def add_tag(tag)
        @tags << tag.to_s unless @tags.include?(tag.to_s)
      end

      def remove_tag(tag)
        @tags.delete(tag.to_s)
      end

      def has_tag?(tag)
        @tags.include?(tag.to_s)
      end

      # Hash-like access methods for compatibility
      def [](key)
        case key.to_s
        when 'created_at'
          @created_at
        when 'benchmark_config'
          @benchmark_config
        when 'tags'
          @tags
        when 'name'
          @name
        when 'description'
          @description
        end
      end

      def []=(key, value)
        case key.to_s
        when 'created_at'
          @created_at = value
        when 'benchmark_config'
          @benchmark_config = value
        when 'tags'
          @tags = Array(value)
        when 'name'
          @name = value
        when 'description'
          @description = value
        end
      end
    end
  end
end
