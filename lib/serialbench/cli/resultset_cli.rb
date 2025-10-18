# frozen_string_literal: true

require_relative 'base_cli'
require_relative '../models/result_set'
require_relative '../site_generator'

module Serialbench
  module Cli
    # CLI for managing benchmark resultsets (collections of runs)
    class ResultsetCli < BaseCli
      desc 'create NAME PATH', 'Create a new resultset'
      long_desc <<~DESC
        Create a new resultset (collection of benchmark runs).

        NAME is required and must be unique.
        PATH is the directory where the resultset will be created.

        Examples:
          serialbench resultset create performance-comparison results/sets/performance-comparison
          serialbench resultset create cross-platform-test results/sets/cross-platform-test
      DESC
      def create(resultset_name, resultset_path)
        Serialbench::Models::ResultStore.default

        # Check if resultset already exists
        definition_path = File.join(resultset_path, 'resultset.yaml')

        if File.exist?(definition_path)
          say "ResultSet at '#{resultset_path}' already exists", :yellow
          return unless yes?('Create anyway with timestamp suffix? (y/n)')

          resultset_path = "#{resultset_path}-#{generate_timestamp}"
        end

        # Create empty resultset using the new ResultSet model
        resultset = Serialbench::Models::ResultSet.new(
          name: resultset_name,
          description: "ResultSet for #{resultset_name} benchmarks",
          created_at: Time.now.utc.iso8601,
          updated_at: Time.now.utc.iso8601
        )
        resultset.save(resultset_path)

        say "✅ Created resultset: #{resultset_path}", :green
        say "Path: #{definition_path}", :cyan
        say "Use 'serialbench resultset add-result' to add benchmark runs", :white
      rescue StandardError => e
        say "Error creating resultset: #{e.message}", :red
        exit 1
      end

      desc 'add-result RESULT_PATH RESULTSET_PATH', 'Add a run to a resultset'
      long_desc <<~DESC
        Add an existing benchmark run to a resultset.

        RESULT_PATH should be the path to a run result directory
        RESULTSET_PATH must be specified explicitly

        Examples:
          serialbench resultset add-result results/sets/performance-comparison results/runs/my-run-local-macos-arm64-ruby-3.3.8
          serialbench resultset add-result results/sets/cross-platform-test results/runs/my-docker-run
      DESC
      def add_result(resultset_path, result_path)
        resultset = Serialbench::Models::ResultSet.load(resultset_path)

        # Validate that the run location exists
        unless Dir.exist?(result_path)
          say "Result directory not found: #{result_path}", :red
          return
        end

        # Add run to resultset
        resultset.add_result(result_path)
        resultset.save(resultset_path)

        say '✅ Added run to resultset', :green
        say "Path: #{result_path}", :cyan
        say "ResultSet: #{resultset_path}", :cyan
        say "Total runs in set: #{resultset.results.count}", :white
      rescue StandardError => e
        say "Error adding run to resultset: #{e.message}", :red
        exit 1
      end

      desc 'remove-result RESULTSET_PATH RESULT_PATH', 'Remove a run from a resultset'
      long_desc <<~DESC
        Remove a benchmark run from a resultset.

        RESULTSET_PATH must be specified explicitly
        RESULT_PATH is the path to the run result directory

        Examples:
          serialbench resultset remove-result results/sets/performance-comparison results/runs/my-run-local-macos-arm64-ruby-3.3.8
          serialbench resultset remove-result results/sets/cross-platform-test results/runs/my-docker-run
      DESC
      def remove_result(resultset_path, _result_path)
        Serialbench::Models::ResultStore.default

        # Find the resultset
        resultset = Serialbench::Models::ResultSet.load(resultset_path)
        if resultset.nil?
          say "ResultSet '#{resultset_path}' not found", :red
          exit 1
        end

        # Remove run from resultset
        removed = resultset.remove_run(run_identifier)
        unless removed
          say "Run '#{run_identifier}' not found in resultset", :yellow
          say 'Available runs in resultset:', :white
          resultset.runs.each do |run_info|
            say "  - #{run_info[:name]}", :white
          end
          return
        end

        resultset.save

        say '✅ Removed run from resultset', :green
        say "Run: #{run_identifier}", :cyan
        say "ResultSet: #{resultset_path}", :cyan
        say "Remaining runs in set: #{resultset.runs.length}", :white
      rescue StandardError => e
        say "Error removing run from resultset: #{e.message}", :red
        exit 1
      end

      desc 'build-site RESULTSET_PATH [OUTPUT_DIR]', 'Generate HTML site for a resultset'
      long_desc <<~DESC
        Generate an HTML site for a resultset (comparative analysis).

        RESULTSET_PATH must be specified explicitly
        OUTPUT_DIR defaults to _site/

        Examples:
          serialbench resultset build-site results/sets/performance-comparison
          serialbench resultset build-site results/sets/cross-platform-test output/
      DESC
      option :output_dir, type: :string, default: '_site', desc: 'Output directory for generated site'
      def build_site(resultset_path)
        unless Dir.exist?(resultset_path)
          say "ResultSet directory not found: #{resultset_path}", :red
          say "Please create a resultset first using 'serialbench resultset create'", :white
          exit 1
        end

        resultset = Serialbench::Models::ResultSet.load(resultset_path)

        if resultset.results.empty?
          say "ResultSet '#{resultset_path}' contains no runs", :yellow
          say "Use 'serialbench resultset add-result' to add runs first", :white
          return
        end

        say "🏗️  Generating HTML site for resultset: #{resultset_path}", :green
        say "Runs in set: #{resultset.results.size}", :cyan

        # Use the unified site generator for resultsets
        Serialbench::SiteGenerator.generate_for_resultset(resultset, options[:output_dir])

        say '✅ HTML site generated successfully!', :green
        say "Site location: #{options[:output_dir]}", :cyan
        say "Open: #{File.join(options[:output_dir], 'index.html')}", :white
      rescue StandardError => e
        say "Error generating site: #{e.message}", :red
        say "Details: #{e.backtrace.first(3).join("\n")}", :red if options[:verbose]
        exit 1
      end

      desc 'list', 'List all available resultsets'
      long_desc <<~DESC
        List all resultsets in the results/sets/ directory.

        Shows resultset names, number of runs, and timestamps.
      DESC
      def list
        ensure_results_directory

        begin
          store = Serialbench::Models::ResultStore.default
          resultsets = store.find_resultsets

          if resultsets.empty?
            say 'No resultsets found', :yellow
            say "Use 'serialbench resultset create' to create a resultset", :white
            return
          end

          say 'Available ResultSets:', :green
          say '=' * 50, :green

          resultsets.each do |resultset|
            say "📁 #{resultset.name}", :cyan
            say "   Runs: #{resultset.runs.length}", :white
            say "   Created: #{resultset.metadata[:timestamp]}", :white
            say "   Path: #{resultset.directory}", :white

            if resultset.runs.any?
              say '   Contains:', :white
              resultset.runs.first(3).each do |run_info|
                say "     - #{run_info[:name]}", :white
              end
              say "     ... and #{resultset.runs.length - 3} more" if resultset.runs.length > 3
            end

            say ''
          end
        rescue StandardError => e
          say "Error listing resultsets: #{e.message}", :red
          exit 1
        end
      end
    end
  end
end
