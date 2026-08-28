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

      desc 'add-result RESULTSET_PATH RESULT_PATH...', 'Add one or more runs to a resultset'
      long_desc <<~DESC
        Add one or more benchmark runs to a resultset.

        RESULTSET_PATH is the path to the resultset directory
        RESULT_PATH... accepts multiple result paths (supports shell expansion)

        Examples:
          # Add single result
          serialbench resultset add-result results/sets/weekly results/runs/my-run

          # Add multiple results explicitly
          serialbench resultset add-result results/sets/weekly results/runs/run1 results/runs/run2

          # Add multiple results with shell expansion
          serialbench resultset add-result results/sets/weekly artifacts/benchmark-results-*/
          serialbench resultset add-result results/sets/weekly results/runs/*
      DESC
      def add_result(resultset_path, *result_paths)
        if result_paths.empty?
          say '❌ Error: At least one result path must be provided', :red
          exit 1
        end

        resultset = Serialbench::Models::ResultSet.load(resultset_path)

        say "📦 Adding #{result_paths.size} result(s) to resultset", :cyan
        say "ResultSet: #{resultset_path}", :white
        say ''

        added_count = 0
        failed_count = 0
        skipped_count = 0

        result_paths.each_with_index do |result_path, index|
          say "#{index + 1}/#{result_paths.size} Processing: #{result_path}", :cyan

          # Find results.yaml in the path or subdirectories
          results_file = if File.exist?(File.join(result_path, 'results.yaml'))
                           File.join(result_path, 'results.yaml')
                         else
                           Dir.glob(File.join(result_path, '**/results.yaml')).first
                         end

          unless results_file
            say '  ⚠️  No results.yaml found - skipping', :yellow
            skipped_count += 1
            next
          end

          result_dir = File.dirname(results_file)

          begin
            resultset.add_result(result_dir)
            say '  ✅ Added successfully', :green
            added_count += 1
          rescue StandardError => e
            say "  ❌ Failed: #{e.message}", :red
            failed_count += 1
          end
          say ''
        end

        resultset.save(resultset_path)

        say '=' * 60, :cyan
        say 'Summary:', :green
        say "  Total processed: #{result_paths.size}", :white
        say "  ✅ Successfully added: #{added_count}", :green
        say "  ❌ Failed: #{failed_count}", :red if failed_count > 0
        say "  ⚠️  Skipped: #{skipped_count}", :yellow if skipped_count > 0
        say "  📊 Total results in set: #{resultset.results.count}", :cyan
        say '=' * 60, :cyan

        exit 1 if failed_count > 0 && added_count == 0
      rescue StandardError => e
        say "❌ Error: #{e.message}", :red
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
      def build_site(resultset_path, output_dir = '_site')
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
        Serialbench::SiteGenerator.generate_for_resultset(resultset, output_dir)

        say '✅ HTML site generated successfully!', :green
        say "Site location: #{output_dir}", :cyan
        say "Open: #{File.join(output_dir, 'index.html')}", :white
      rescue StandardError => e
        say "Error generating site: #{e.message}", :red
        say "Details: #{e.backtrace.first(3).join("\n")}", :red if options[:verbose]
        exit 1
      end

      desc 'export-data RESULTSET_PATH OUTPUT_JSON', 'Export a resultset as the site dashboard JSON payload'
      long_desc <<~DESC
        Write the aggregated dashboard payload (combined_results, environments,
        metadata) for a resultset as JSON. This is the data contract consumed
        by the Astro site in site/.

        Optionally also export the raw per-environment YAML files and the
        complete resultset YAML for download links.

        Examples:
          serialbench resultset export-data results/sets/weekly site/src/data/sample.json --raw-data-dir site/public/data
      DESC
      method_option 'raw-data-dir', type: :string,
                                     desc: 'Also write per-environment YAML and resultset.yaml to this directory'
      def export_data(resultset_path, output_json)
        resultset = Serialbench::Models::ResultSet.load(resultset_path)

        if resultset.results.empty?
          say "ResultSet '#{resultset_path}' contains no runs", :yellow
          say "Use 'serialbench resultset add-result' to add runs first", :white
          exit 1
        end

        payload = Serialbench::SiteGenerator.resultset_payload(resultset)
        output_dir = File.dirname(File.expand_path(output_json))
        FileUtils.mkdir_p(output_dir)
        File.write(output_json, JSON.pretty_generate(payload))

        say "✅ Dashboard payload exported: #{output_json}", :green
        say "Environments: #{payload['environments'].size}", :cyan

        if options['raw-data-dir']
          Serialbench::SiteGenerator.export_raw_data(resultset, options['raw-data-dir'])
          say "📦 Raw YAML exported to: #{options['raw-data-dir']}", :cyan
        end
      rescue StandardError => e
        say "Error exporting data: #{e.message}", :red
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
