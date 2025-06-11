# frozen_string_literal: true

require_relative 'run_set_result'
require_relative 'result_store'

module Serialbench
  module Models
    class RunSetManager
      attr_reader :result_store

      def initialize(result_store = nil)
        @result_store = result_store || ResultStore.default
      end

      def self.default
        @default ||= new
      end

      # Create a new run set from run platform strings
      def create(name, run_platform_strings, metadata: {})
        @result_store.create_run_set(name, run_platform_strings, metadata: metadata)
      end

      # Create a run set from existing RunResult objects
      def create_from_runs(name, run_results, metadata: {})
        run_set = RunSetResult.create(name, run_results, metadata: metadata)
        @result_store.save_run_set(run_set)
        run_set
      end

      # Load an existing run set
      def load(name_with_timestamp)
        @result_store.find_run_set(name_with_timestamp)
      end

      # Find run sets by various criteria
      def find_all
        @result_store.find_run_sets
      end

      def find_by_tags(tags)
        @result_store.find_run_sets(tags: tags)
      end

      def find_by_name_pattern(pattern)
        find_all.select { |runset| runset.name.match?(pattern) }
      end

      def find_recent(limit = 5)
        @result_store.latest_run_sets(limit)
      end

      # Update operations
      def add_run_to_set(run_set_name_with_timestamp, run_platform_string)
        run_set = load(run_set_name_with_timestamp)
        return nil unless run_set

        run_path = File.join(@result_store.runs_path, run_platform_string)
        run_set.add_run(run_path)
        @result_store.save_run_set(run_set)
        run_set
      end

      def remove_run_from_set(run_set_name_with_timestamp, run_platform_string)
        run_set = load(run_set_name_with_timestamp)
        return nil unless run_set

        run_set.remove_run(run_platform_string)
        @result_store.save_run_set(run_set)
        run_set
      end

      # Bulk operations
      def create_from_tag_filter(name, tags, metadata: {})
        matching_runs = @result_store.find_runs(tags: tags)
        return nil if matching_runs.empty?

        create_from_runs(name, matching_runs, metadata: metadata)
      end

      def create_cross_platform_comparison(name, ruby_versions: nil, metadata: {})
        runs = @result_store.find_runs

        if ruby_versions
          runs = runs.select { |run| ruby_versions.include?(run.ruby_version) }
        end

        return nil if runs.empty?

        # Group by ruby version and select one docker and one local run for each
        comparison_runs = []
        runs.group_by(&:ruby_version).each do |version, version_runs|
          docker_run = version_runs.find { |r| r.platform.docker? }
          local_run = version_runs.find { |r| r.platform.local? }

          comparison_runs << docker_run if docker_run
          comparison_runs << local_run if local_run
        end

        return nil if comparison_runs.empty?

        create_from_runs(name, comparison_runs, metadata: metadata.merge(
          description: "Cross-platform comparison for Ruby versions: #{comparison_runs.map(&:ruby_version).uniq.sort.join(', ')}"
        ))
      end

      def create_ruby_version_comparison(name, platforms: nil, metadata: {})
        runs = @result_store.find_runs

        if platforms
          runs = runs.select { |run| platforms.include?(run.platform.runtime) }
        end

        return nil if runs.empty?

        # Group by platform and select runs across different Ruby versions
        comparison_runs = []
        runs.group_by { |r| r.platform.runtime }.each do |platform, platform_runs|
          # Take the latest run for each Ruby version on this platform
          platform_runs.group_by(&:ruby_version).each do |version, version_runs|
            comparison_runs << version_runs.sort_by(&:created_at).last
          end
        end

        return nil if comparison_runs.empty?

        create_from_runs(name, comparison_runs, metadata: metadata.merge(
          description: "Ruby version comparison across platforms: #{comparison_runs.map { |r| r.platform.runtime }.uniq.sort.join(', ')}"
        ))
      end

      # Analysis methods
      def analyze_run_set(run_set)
        {
          name: run_set.name,
          created_at: run_set.created_at,
          run_count: run_set.run_count,
          ruby_versions: run_set.ruby_versions,
          platforms: run_set.platforms,
          tags: run_set.tags,
          performance_summary: analyze_performance(run_set),
          memory_summary: analyze_memory(run_set)
        }
      end

      def compare_run_sets(run_set1, run_set2)
        {
          run_set_1: {
            name: run_set1.name,
            run_count: run_set1.run_count,
            ruby_versions: run_set1.ruby_versions,
            platforms: run_set1.platforms
          },
          run_set_2: {
            name: run_set2.name,
            run_count: run_set2.run_count,
            ruby_versions: run_set2.ruby_versions,
            platforms: run_set2.platforms
          },
          common_platforms: run_set1.platforms & run_set2.platforms,
          common_ruby_versions: run_set1.ruby_versions & run_set2.ruby_versions,
          unique_to_set_1: run_set1.platforms - run_set2.platforms,
          unique_to_set_2: run_set2.platforms - run_set1.platforms
        }
      end

      # Cleanup operations
      def delete(name_with_timestamp)
        @result_store.delete_run_set(name_with_timestamp)
      end

      def cleanup_old_sets(days_old = 30)
        @result_store.cleanup_old_run_sets(days_old)
      end

      # Validation
      def validate_run_set(run_set)
        errors = []

        begin
          run_set.validate!
        rescue => e
          errors << "Run set validation failed: #{e.message}"
        end

        # Check that all referenced runs exist
        run_set.runs.each do |run|
          unless run.path && Dir.exist?(run.path)
            errors << "Referenced run does not exist: #{run.platform_string}"
          end
        end

        errors
      end

      def repair_run_set(run_set)
        # Remove runs that no longer exist
        valid_runs = run_set.runs.select { |run| run.path && Dir.exist?(run.path) }

        if valid_runs.length != run_set.runs.length
          puts "Removing #{run_set.runs.length - valid_runs.length} invalid run references"

          # Create new run set with only valid runs
          repaired_set = RunSetResult.create(
            run_set.name,
            valid_runs,
            metadata: run_set.metadata.to_hash
          )

          @result_store.save_run_set(repaired_set)
          repaired_set
        else
          run_set
        end
      end

      private

      def analyze_performance(run_set)
        return {} unless run_set.merged_result

        # Extract performance metrics from merged result
        combined_results = run_set.merged_result.combined_results

        summary = {}

        [:parsing, :generation, :streaming].each do |operation|
          operation_results = combined_results.send(operation)
          next if operation_results.empty?

          summary[operation] = analyze_operation_performance(operation_results)
        end

        summary
      end

      def analyze_memory(run_set)
        return {} unless run_set.merged_result

        combined_results = run_set.merged_result.combined_results
        memory_results = combined_results.memory

        return {} if memory_results.empty?

        analyze_memory_results(memory_results)
      end

      def analyze_operation_performance(operation_results)
        summary = {}

        [:small, :medium, :large].each do |size|
          size_results = operation_results.send(size)
          next if size_results.empty?

          summary[size] = analyze_size_performance(size_results)
        end

        summary
      end

      def analyze_size_performance(size_results)
        summary = {}

        [:xml, :json, :yaml, :toml].each do |format|
          format_results = size_results.send(format)
          next if format_results.empty?

          # Find fastest and slowest serializers
          serializer_times = {}
          format_results.serializers.each do |serializer|
            env_results = format_results[serializer]
            avg_time = env_results.values.map { |perf| perf.time_per_iteration }.compact.sum / env_results.size.to_f
            serializer_times[serializer] = avg_time if avg_time > 0
          end

          if serializer_times.any?
            sorted_times = serializer_times.sort_by { |_, time| time }
            summary[format] = {
              fastest: sorted_times.first,
              slowest: sorted_times.last,
              serializer_count: serializer_times.size
            }
          end
        end

        summary
      end

      def analyze_memory_results(memory_results)
        # Similar analysis for memory usage
        summary = {}

        [:small, :medium, :large].each do |size|
          size_results = memory_results.send(size)
          next if size_results.empty?

          summary[size] = analyze_size_memory(size_results)
        end

        summary
      end

      def analyze_size_memory(size_results)
        summary = {}

        [:xml, :json, :yaml, :toml].each do |format|
          format_results = size_results.send(format)
          next if format_results.empty?

          # Find most and least memory-efficient serializers
          serializer_memory = {}
          format_results.serializers.each do |serializer|
            env_results = format_results[serializer]
            avg_memory = env_results.values.map { |mem| mem.total_allocated }.compact.sum / env_results.size.to_f
            serializer_memory[serializer] = avg_memory if avg_memory > 0
          end

          if serializer_memory.any?
            sorted_memory = serializer_memory.sort_by { |_, memory| memory }
            summary[format] = {
              most_efficient: sorted_memory.first,
              least_efficient: sorted_memory.last,
              serializer_count: serializer_memory.size
            }
          end
        end

        summary
      end
    end
  end
end
