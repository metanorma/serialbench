# frozen_string_literal: true

require 'fileutils'
require_relative 'run_result'
require_relative 'run_set_result'

module Serialbench
  module Models
    class ResultStore
      DEFAULT_BASE_PATH = 'results'
      RUNS_PATH = 'runs'
      SETS_PATH = 'sets'

      attr_reader :base_path

      def initialize(base_path = DEFAULT_BASE_PATH)
        @base_path = base_path
        ensure_directory_structure
      end

      def self.default
        @default ||= new
      end

      # Run management
      def runs_path
        File.join(@base_path, RUNS_PATH)
      end

      def find_runs(tags: nil, limit: nil)
        runs = RunResult.find_all(runs_path)

        if tags
          runs = runs.select { |run| (Array(tags) - run.tags).empty? }
        end

        runs = runs.sort_by(&:created_at).reverse

        limit ? runs.first(limit) : runs
      end

      def find_run(platform_string)
        RunResult.load(File.join(runs_path, platform_string))
      rescue ArgumentError
        nil
      end

      def save_run(run_result)
        run_result.save(runs_path)
      end

      def delete_run(platform_string)
        run_path = File.join(runs_path, platform_string)
        FileUtils.rm_rf(run_path) if Dir.exist?(run_path)
      end

      def run_exists?(platform_string)
        Dir.exist?(File.join(runs_path, platform_string))
      end

      # Run set management
      def sets_path
        File.join(@base_path, SETS_PATH)
      end

      def find_run_sets(tags: nil, limit: nil)
        run_sets = RunSetResult.find_all(sets_path)

        if tags
          run_sets = run_sets.select { |runset| (Array(tags) - runset.tags).empty? }
        end

        run_sets = run_sets.sort_by(&:created_at).reverse

        limit ? run_sets.first(limit) : run_sets
      end

      def find_run_set(name_with_timestamp)
        RunSetResult.load(File.join(sets_path, name_with_timestamp))
      rescue ArgumentError
        nil
      end

      def save_run_set(run_set_result)
        run_set_result.save(sets_path)
      end

      def delete_run_set(name_with_timestamp)
        set_path = File.join(sets_path, name_with_timestamp)
        FileUtils.rm_rf(set_path) if Dir.exist?(set_path)
      end

      def run_set_exists?(name_with_timestamp)
        Dir.exist?(File.join(sets_path, name_with_timestamp))
      end

      # Convenience methods
      def create_run_set(name, run_platform_strings, metadata: {})
        run_paths = run_platform_strings.map { |ps| File.join(runs_path, ps) }
        run_set = RunSetResult.create(name, run_paths, metadata: metadata)
        save_run_set(run_set)
        run_set
      end

      def latest_runs(count = 5)
        find_runs(limit: count)
      end

      def latest_run_sets(count = 5)
        find_run_sets(limit: count)
      end

      # Statistics
      def stats
        runs = find_runs
        run_sets = find_run_sets

        {
          'total_runs' => runs.length,
          'total_run_sets' => run_sets.length,
          'ruby_versions' => runs.map(&:ruby_version).uniq.sort,
          'platforms' => runs.map { |r| r.platform.runtime }.uniq.sort,
          'tags' => runs.flat_map(&:tags).uniq.sort,
          'latest_run' => runs.first&.created_at,
          'latest_run_set' => run_sets.first&.created_at,
          'disk_usage' => calculate_disk_usage
        }
      end

      # Cleanup operations
      def cleanup_old_runs(days_old = 30)
        cutoff_date = Time.now - (days_old * 24 * 60 * 60)

        runs = find_runs
        old_runs = runs.select { |run| Time.parse(run.created_at) < cutoff_date }

        old_runs.each do |run|
          delete_run(run.platform_string)
        end

        old_runs.length
      end

      def cleanup_old_run_sets(days_old = 30)
        cutoff_date = Time.now - (days_old * 24 * 60 * 60)

        run_sets = find_run_sets
        old_sets = run_sets.select { |set| Time.parse(set.created_at) < cutoff_date }

        old_sets.each do |set|
          delete_run_set(File.basename(set.path))
        end

        old_sets.length
      end

      # Validation
      def validate_structure
        errors = []

        # Check base structure
        unless Dir.exist?(@base_path)
          errors << "Base path does not exist: #{@base_path}"
        end

        unless Dir.exist?(runs_path)
          errors << "Runs directory does not exist: #{runs_path}"
        end

        unless Dir.exist?(sets_path)
          errors << "Sets directory does not exist: #{sets_path}"
        end

        # Validate individual runs
        if Dir.exist?(runs_path)
          Dir.glob(File.join(runs_path, '*')).each do |run_path|
            next unless Dir.exist?(run_path)

            begin
              run = RunResult.load(run_path)
              run.validate!
            rescue => e
              errors << "Invalid run at #{run_path}: #{e.message}"
            end
          end
        end

        # Validate run sets
        if Dir.exist?(sets_path)
          Dir.glob(File.join(sets_path, '*')).each do |set_path|
            next unless Dir.exist?(set_path)

            begin
              run_set = RunSetResult.load(set_path)
              run_set.validate!
            rescue => e
              errors << "Invalid run set at #{set_path}: #{e.message}"
            end
          end
        end

        errors
      end

      def valid?
        validate_structure.empty?
      end

      # Migration helpers
      def migrate_from_old_structure(old_paths)
        migrated_count = 0

        old_paths.each do |old_path|
          next unless Dir.exist?(old_path)

          begin
            # Try to determine if it's a single run or multiple runs
            if has_benchmark_data?(old_path)
              # Single run
              migrate_single_run(old_path)
              migrated_count += 1
            else
              # Multiple runs directory
              Dir.glob(File.join(old_path, '*')).each do |sub_path|
                if Dir.exist?(sub_path) && has_benchmark_data?(sub_path)
                  migrate_single_run(sub_path)
                  migrated_count += 1
                end
              end
            end
          rescue => e
            warn "Failed to migrate #{old_path}: #{e.message}"
          end
        end

        migrated_count
      end

      private

      def ensure_directory_structure
        FileUtils.mkdir_p(runs_path)
        FileUtils.mkdir_p(sets_path)
      end

      def calculate_disk_usage
        return 0 unless Dir.exist?(@base_path)

        total_size = 0
        Dir.glob(File.join(@base_path, '**', '*')).each do |file|
          total_size += File.size(file) if File.file?(file)
        end

        # Return size in MB
        (total_size / 1024.0 / 1024.0).round(2)
      end

      def has_benchmark_data?(path)
        data_dir = File.join(path, 'data')
        return false unless Dir.exist?(data_dir)

        File.exist?(File.join(data_dir, 'results.yaml')) ||
          File.exist?(File.join(data_dir, 'results.json'))
      end

      def migrate_single_run(old_path)
        # Load the old result
        data_file = File.join(old_path, 'data', 'results.yaml')
        data_file = File.join(old_path, 'data', 'results.json') unless File.exist?(data_file)

        return unless File.exist?(data_file)

        benchmark_result = Serialbench::Models::BenchmarkResult.from_file(data_file)

        # Create platform from path name or detect from data
        platform_string = detect_platform_string(old_path, benchmark_result)

        # Create run result
        run_result = RunResult.create(platform_string, benchmark_result.to_hash)

        # Save to new structure
        save_run(run_result)

        puts "Migrated #{old_path} -> #{run_result.path}"
      end

      def detect_platform_string(old_path, benchmark_result)
        path_name = File.basename(old_path)

        # Try to parse existing path names
        if path_name.match(/ruby-(\d+\.\d+)/)
          ruby_version = $1

          if path_name.include?('docker')
            variant = path_name.include?('alpine') ? 'alpine' : 'slim'
            arch = 'arm64' # Default, could be improved with detection
            "docker-#{variant}-#{arch}-ruby-#{ruby_version}"
          else
            # Local run
            platform = Serialbench::Models::Platform.current_local(ruby_version: "#{ruby_version}.0")
            platform.platform_string
          end
        else
          # Fallback to current platform
          platform = Serialbench::Models::Platform.current_local
          platform.platform_string
        end
      end
    end
  end
end
