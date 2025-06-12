# frozen_string_literal: true

require 'fileutils'
require_relative 'result'

module Serialbench
  module Models
    class ResultStore
      DEFAULT_BASE_PATH = 'results'
      RUNS_PATH = 'runs'
      SETS_PATH = 'sets'

      attr_reader :base_path

      def initialize(base_path = DEFAULT_BASE_PATH)
        @base_path = base_path
        ensure_results_directory
      end

      def self.default
        @default ||= new
      end

      # Run management
      def runs_path
        File.join(@base_path, RUNS_PATH)
      end

      def find_runs(tags: nil, limit: nil)
        runs = Result.find_all(runs_path)

        runs = runs.select { |run| (Array(tags) - run.tags).empty? } if tags

        limit ? runs.first(limit) : runs
      end

      # Run set management
      def sets_path
        File.join(@base_path, SETS_PATH)
      end

      def find_resultsets(tags: nil, limit: nil)
        resultsets = ResultSet.find_all(sets_path)

        resultsets = resultsets.select { |resultset| (Array(tags) - resultset.tags).empty? } if tags

        limit ? resultsets.first(limit) : resultsets
      end

      # Convenience methods
      def create_resultset(name, run_platform_strings, metadata: {})
        run_paths = run_platform_strings.map { |ps| File.join(runs_path, ps) }
        resultset = ResultSet.create(name, run_paths, metadata: metadata)
        save_resultset(resultset)
        resultset
      end

      # Validation
      def validate_structure
        errors = []

        # Check base structure
        errors << "Base path does not exist: #{@base_path}" unless Dir.exist?(@base_path)
        errors << "Runs directory does not exist: #{runs_path}" unless Dir.exist?(runs_path)
        errors << "Sets directory does not exist: #{sets_path}" unless Dir.exist?(sets_path)

        # Validate individual runs
        if Dir.exist?(runs_path)
          Dir.glob(File.join(runs_path, '*')).each do |run_path|
            next unless Dir.exist?(run_path)

            begin
              run = Result.load(run_path)
              run.validate!
            rescue StandardError => e
              errors << "Invalid result at #{run_path}: #{e.message}"
            end
          end
        end

        # Validate result sets
        if Dir.exist?(sets_path)
          Dir.glob(File.join(sets_path, '*')).each do |set_path|
            next unless Dir.exist?(set_path)

            begin
              resultset = ResultSet.load(set_path)
              resultset.validate!
            rescue StandardError => e
              errors << "Invalid result set at #{set_path}: #{e.message}"
            end
          end
        end

        errors
      end

      def valid?
        validate_structure.empty?
      end

      def ensure_results_directory
        FileUtils.mkdir_p(runs_path) unless Dir.exist?(runs_path)
        FileUtils.mkdir_p(sets_path) unless Dir.exist?(sets_path)
      end
    end
  end
end
