# frozen_string_literal: true

require 'yaml'
require 'json'
require 'time'
require 'fileutils'
require_relative 'run_result'
require_relative 'merged_benchmark_result'

module Serialbench
  module Models
    class RunSetResult
      attr_reader :name, :runs, :merged_result, :metadata, :path

      def initialize(name:, runs: [], merged_result: nil, metadata: {}, path: nil)
        @name = name
        @runs = runs.map { |run| run.is_a?(RunResult) ? run : RunResult.load(run) }
        @merged_result = merged_result
        @metadata = RunSetMetadata.new(metadata.merge(name: name))
        @path = path
      end

      def self.create(name, run_paths_or_objects, metadata: {})
        runs = run_paths_or_objects.map do |run|
          run.is_a?(RunResult) ? run : RunResult.load(run)
        end

        # Create merged result from runs
        merged_result = merge_runs(runs)

        new(
          name: name,
          runs: runs,
          merged_result: merged_result,
          metadata: metadata
        )
      end

      def self.load(path)
        raise ArgumentError, "Path does not exist: #{path}" unless Dir.exist?(path)

        # Load metadata
        metadata_file = File.join(path, 'metadata.yaml')
        raise ArgumentError, "No metadata found in #{path}" unless File.exist?(metadata_file)

        metadata = YAML.load_file(metadata_file)
        name = metadata['name'] || File.basename(path).split('-')[0..-2].join('-')

        # Load merged result
        merged_file = File.join(path, 'merged_results.yaml')
        merged_file = File.join(path, 'merged_results.json') unless File.exist?(merged_file)

        merged_result = nil
        if File.exist?(merged_file)
          merged_result = MergedBenchmarkResult.from_file(merged_file)
        end

        # Load individual runs (optional - they might be referenced by path)
        runs = []
        if metadata['runs_included']
          metadata['runs_included'].each do |run_path|
            begin
              runs << RunResult.load(run_path) if Dir.exist?(run_path)
            rescue => e
              warn "Failed to load run from #{run_path}: #{e.message}"
            end
          end
        end

        new(
          name: name,
          runs: runs,
          merged_result: merged_result,
          metadata: metadata,
          path: path
        )
      end

      def self.find_all(base_path = 'results/sets')
        return [] unless Dir.exist?(base_path)

        Dir.glob(File.join(base_path, '*')).select { |path| Dir.exist?(path) }.map do |path|
          begin
            load(path)
          rescue => e
            warn "Failed to load run set from #{path}: #{e.message}"
            nil
          end
        end.compact
      end

      def self.find_by_tags(tags, base_path = 'results/sets')
        find_all(base_path).select { |runset| (tags - runset.tags).empty? }
      end

      def save(base_path = 'results/sets')
        timestamp = Time.now.utc.iso8601.gsub(':', '')
        dir_name = "#{@name}-#{timestamp}"
        @path = File.join(base_path, dir_name)

        # Create directory structure
        FileUtils.mkdir_p(@path)
        FileUtils.mkdir_p(File.join(@path, 'runs'))

        # Update metadata with current info
        @metadata.created_at = Time.now.utc.iso8601
        @metadata.runs_included = @runs.map(&:path).compact
        @metadata.run_count = @runs.length

        # Save merged result
        if @merged_result
          @merged_result.to_yaml_file(File.join(@path, 'merged_results.yaml'))
          @merged_result.to_json_file(File.join(@path, 'merged_results.json'))
        end

        # Save metadata
        File.write(File.join(@path, 'metadata.yaml'), @metadata.to_yaml)
        File.write(File.join(@path, 'metadata.json'), @metadata.to_json)

        # Save run summaries (not full data, just references)
        run_summaries = @runs.map do |run|
          {
            'platform_string' => run.platform_string,
            'ruby_version' => run.ruby_version,
            'created_at' => run.created_at,
            'path' => run.path,
            'tags' => run.tags
          }
        end
        File.write(File.join(@path, 'runs', 'summary.yaml'), run_summaries.to_yaml)
        File.write(File.join(@path, 'runs', 'summary.json'), JSON.pretty_generate(run_summaries))

        self
      end

      def add_run(run_or_path)
        run = run_or_path.is_a?(RunResult) ? run_or_path : RunResult.load(run_or_path)
        @runs << run
        @merged_result = self.class.merge_runs(@runs)
        update_metadata_from_runs
        self
      end

      def remove_run(platform_string)
        @runs.reject! { |run| run.platform_string == platform_string }
        @merged_result = self.class.merge_runs(@runs) if @runs.any?
        update_metadata_from_runs
        self
      end

      def tags
        @metadata.tags
      end

      def created_at
        @metadata.created_at
      end

      def run_count
        @runs.length
      end

      def ruby_versions
        @runs.map(&:ruby_version).uniq.sort
      end

      def platforms
        @runs.map(&:platform_string).sort
      end

      def has_run?(platform_string)
        @runs.any? { |run| run.platform_string == platform_string }
      end

      def get_run(platform_string)
        @runs.find { |run| run.platform_string == platform_string }
      end

      def to_hash
        {
          'name' => @name,
          'metadata' => @metadata.to_hash,
          'merged_result' => @merged_result&.to_hash,
          'runs' => @runs.map(&:to_hash),
          'path' => @path
        }.reject { |_, v| v.nil? }
      end

      def to_yaml
        to_hash.to_yaml
      end

      def to_json
        JSON.pretty_generate(to_hash)
      end

      def valid?
        @runs.all?(&:valid?) && @metadata.valid?
      end

      def validate!
        @runs.each(&:validate!)
        @metadata.validate!
      end

      private

      def self.merge_runs(runs)
        return nil if runs.empty?

        # Use existing result merger logic
        merger = Serialbench::ResultMerger.new
        benchmark_results = runs.map(&:benchmark_result).compact

        return nil if benchmark_results.empty?

        # Create temporary files for merging
        temp_files = []
        begin
          benchmark_results.each_with_index do |result, index|
            temp_file = "/tmp/temp_result_#{index}_#{Time.now.to_i}.yaml"
            result.to_yaml_file(temp_file)
            temp_files << temp_file
          end

          merged_data = merger.merge_files(temp_files)
          MergedBenchmarkResult.new(merged_data)
        ensure
          temp_files.each { |file| File.delete(file) if File.exist?(file) }
        end
      end

      def update_metadata_from_runs
        # Update tags from all runs
        all_tags = @runs.flat_map(&:tags).uniq.sort
        @metadata.tags = all_tags

        # Update run count
        @metadata.run_count = @runs.length

        # Update runs included
        @metadata.runs_included = @runs.map(&:path).compact
      end
    end

    class RunSetMetadata
      attr_accessor :name, :created_at, :runs_included, :run_count, :tags, :description

      def initialize(data = {})
        @name = data['name'] || data[:name]
        @created_at = data['created_at'] || data[:created_at] || Time.now.utc.iso8601
        @runs_included = Array(data['runs_included'] || data[:runs_included])
        @run_count = data['run_count'] || data[:run_count] || 0
        @tags = Array(data['tags'] || data[:tags])
        @description = data['description'] || data[:description]
      end

      def to_hash
        {
          'name' => @name,
          'created_at' => @created_at,
          'runs_included' => @runs_included,
          'run_count' => @run_count,
          'tags' => @tags,
          'description' => @description
        }.reject { |_, v| v.nil? || (v.respond_to?(:empty?) && v.empty?) }
      end

      def to_yaml
        to_hash.to_yaml
      end

      def to_json
        JSON.pretty_generate(to_hash)
      end

      def valid?
        !@name.nil? && !@created_at.nil?
      end

      def validate!
        raise ArgumentError, "name is required" if @name.nil?
        raise ArgumentError, "created_at is required" if @created_at.nil?
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
    end
  end
end
