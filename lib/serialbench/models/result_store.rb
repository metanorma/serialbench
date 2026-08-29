# frozen_string_literal: true

require 'fileutils'
require_relative 'result'

module Serialbench
  module Models
    class ResultStore
      DEFAULT_BASE_PATH = 'results'
      RUNS_PATH = 'runs'

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

      # Validation
      def validate_structure
        errors = []

        # Check base structure
        errors << "Base path does not exist: #{@base_path}" unless Dir.exist?(@base_path)
        errors << "Runs directory does not exist: #{runs_path}" unless Dir.exist?(runs_path)

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

        errors
      end

      def valid?
        validate_structure.empty?
      end

      def ensure_results_directory
        FileUtils.mkdir_p(runs_path) unless Dir.exist?(runs_path)
      end
    end
  end
end
