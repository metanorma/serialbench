# frozen_string_literal: true

require_relative 'base_cli'
require_relative '../models/result_set'
require_relative '../models/result'
require_relative '../site_generator'
require_relative '../renderers/runset_renderer'

module Serialbench
  module Cli
    # CLI for managing benchmark runsets (collections of runs)
    class RunsetCli < BaseCli
      desc 'create NAME', 'Create a new runset'
      long_desc <<~DESC
        Create a new runset (collection of benchmark runs).

        NAME is required and must be unique.

        Examples:
          serialbench runset create performance-comparison
          serialbench runset create cross-platform-test
      DESC
      def create(name)
        validate_name(name)
        ensure_results_directory

        begin
          # Check if runset already exists
          resultsets_dir = 'resultsets'
          FileUtils.mkdir_p(resultsets_dir)

          resultset_path = File.join(resultsets_dir, "#{name}.yml")
          if File.exist?(resultset_path)
            say "Runset with name '#{name}' already exists", :yellow
            return unless yes?('Create anyway with timestamp suffix? (y/n)')

            name = "#{name}-#{generate_timestamp}"
            resultset_path = File.join(resultsets_dir, "#{name}.yml")
          end

          # Create empty runset using the new ResultSet model
          runset = Serialbench::Models::ResultSet.create(name)
          runset.save_to_file(resultset_path)

          say "✅ Created runset: #{name}", :green
          say "Path: #{resultset_path}", :cyan
          say "Use 'serialbench runset add-run' to add benchmark runs", :white
        rescue StandardError => e
          say "Error creating runset: #{e.message}", :red
          exit 1
        end
      end

      desc 'add-run RUN_LOCATION RUNSET_NAME', 'Add a run to a runset'
      long_desc <<~DESC
        Add an existing benchmark run to a runset.

        RUN_LOCATION should be the path to a run directory or run name
        RUNSET_NAME must be specified explicitly

        Examples:
          serialbench runset add-run results/runs/my-run-local-macos-arm64-ruby-3.3.8 performance-comparison
          serialbench runset add-run my-docker-run cross-platform-test
      DESC
      def add_run(run_location, runset_name)
        validate_name(runset_name)

        begin
          # Find the runset
          resultsets_dir = 'resultsets'
          resultset_path = File.join(resultsets_dir, "#{runset_name}.yml")

          unless File.exist?(resultset_path)
            say "Runset '#{runset_name}' not found", :red
            say "Expected path: #{resultset_path}", :yellow
            return
          end

          runset = Serialbench::Models::ResultSet.load_from_file(resultset_path)

          # Validate that the run location exists
          unless Dir.exist?(run_location)
            say "Run directory not found: #{run_location}", :red
            return
          end

          # Extract run name from path
          run_name = File.basename(run_location)

          # Add run to runset
          runset.add_result(run_name, run_location)
          runset.save_to_file(resultset_path)

          say '✅ Added run to runset', :green
          say "Run: #{run_name}", :cyan
          say "Path: #{run_location}", :cyan
          say "Runset: #{runset.name}", :cyan
          say "Total runs in set: #{runset.result_count}", :white
        rescue StandardError => e
          say "Error adding run to runset: #{e.message}", :red
          exit 1
        end
      end

      desc 'remove-run RUN_IDENTIFIER RUNSET_NAME', 'Remove a run from a runset'
      long_desc <<~DESC
        Remove a benchmark run from a runset.

        RUN_IDENTIFIER can be the run name or path
        RUNSET_NAME must be specified explicitly

        Examples:
          serialbench runset remove-run my-run-local-macos-arm64-ruby-3.3.8 performance-comparison
          serialbench runset remove-run results/runs/docker-run cross-platform-test
      DESC
      def remove_run(run_identifier, runset_name)
        validate_name(runset_name)

        begin
          store = Serialbench::Models::ResultStore.default

          # Find the runset
          runsets = store.find_run_sets(name: runset_name)
          if runsets.empty?
            say "Runset '#{runset_name}' not found", :red
            exit 1
          end

          runset = runsets.first

          # Remove run from runset
          removed = runset.remove_run(run_identifier)
          unless removed
            say "Run '#{run_identifier}' not found in runset", :yellow
            say 'Available runs in runset:', :white
            runset.runs.each do |run_info|
              say "  - #{run_info[:name]}", :white
            end
            return
          end

          runset.save

          say '✅ Removed run from runset', :green
          say "Run: #{run_identifier}", :cyan
          say "Runset: #{runset.name}", :cyan
          say "Remaining runs in set: #{runset.runs.length}", :white
        rescue StandardError => e
          say "Error removing run from runset: #{e.message}", :red
          exit 1
        end
      end

      desc 'build-site RUNSET_NAME [OUTPUT_DIR]', 'Generate HTML site for a runset'
      long_desc <<~DESC
        Generate an HTML site for a runset (comparative analysis).

        RUNSET_NAME must be specified explicitly
        OUTPUT_DIR defaults to _site/

        Examples:
          serialbench runset build-site performance-comparison
          serialbench runset build-site cross-platform-test output/
      DESC
      def build_site(runset_name, output_dir = '_site')
        validate_name(runset_name)

        begin
          # Find the runset
          resultsets_dir = 'resultsets'
          resultset_path = File.join(resultsets_dir, "#{runset_name}.yml")

          unless File.exist?(resultset_path)
            say "Runset '#{runset_name}' not found", :red
            say "Expected path: #{resultset_path}", :yellow
            return
          end

          runset = Serialbench::Models::ResultSet.load_from_file(resultset_path)

          if runset.empty?
            say "Runset '#{runset_name}' contains no runs", :yellow
            say "Use 'serialbench runset add-run' to add runs first", :white
            return
          end

          say "🏗️  Generating HTML site for runset: #{runset.name}", :green
          say "Runs in set: #{runset.result_count}", :cyan

          # Use the proper site generator with runset renderer
          renderer = Serialbench::Renderers::RunsetRenderer.new
          renderer.render(runset, output_dir)

          say '✅ HTML site generated successfully!', :green
          say "Site location: #{output_dir}", :cyan
          say "Open: #{File.join(output_dir, 'index.html')}", :white
        rescue StandardError => e
          say "Error generating site: #{e.message}", :red
          say "Details: #{e.backtrace.first(3).join("\n")}", :red if options[:verbose]
          exit 1
        end
      end

      desc 'list', 'List all available runsets'
      long_desc <<~DESC
        List all runsets in the results/sets/ directory.

        Shows runset names, number of runs, and timestamps.
      DESC
      option :limit, type: :numeric, default: 20, desc: 'Maximum number of runsets to show'
      def list
        ensure_results_directory

        begin
          store = Serialbench::Models::ResultStore.default
          runsets = store.find_run_sets(limit: options[:limit])

          if runsets.empty?
            say 'No runsets found', :yellow
            say "Use 'serialbench runset create' to create a runset", :white
            return
          end

          say 'Available Runsets:', :green
          say '=' * 50, :green

          runsets.each do |runset|
            say "📁 #{runset.name}", :cyan
            say "   Runs: #{runset.runs.length}", :white
            say "   Created: #{runset.metadata[:timestamp]}", :white
            say "   Path: #{runset.directory}", :white

            if runset.runs.any?
              say '   Contains:', :white
              runset.runs.first(3).each do |run_info|
                say "     - #{run_info[:name]}", :white
              end
              say "     ... and #{runset.runs.length - 3} more" if runset.runs.length > 3
            end

            say ''
          end
        rescue StandardError => e
          say "Error listing runsets: #{e.message}", :red
          exit 1
        end
      end

      desc 'show RUNSET_NAME', 'Show details of a specific runset'
      long_desc <<~DESC
        Show detailed information about a specific runset.

        RUNSET_NAME must be specified explicitly

        Examples:
          serialbench runset show performance-comparison
          serialbench runset show cross-platform-test
      DESC
      def show(runset_name)
        validate_name(runset_name)

        begin
          store = Serialbench::Models::ResultStore.default

          # Find the runset
          runsets = store.find_run_sets(name: runset_name)
          if runsets.empty?
            say "Runset '#{runset_name}' not found", :red
            exit 1
          end

          runset = runsets.first

          say 'Runset Details:', :green
          say '=' * 50, :green
          say "Name: #{runset.name}", :cyan
          say "Created: #{runset.metadata[:timestamp]}", :white
          say "Path: #{runset.directory}", :white
          say "Total runs: #{runset.runs.length}", :white
          say ''

          if runset.runs.any?
            say 'Contained Runs:', :yellow
            runset.runs.each do |run_info|
              say "  📊 #{run_info[:name]}", :cyan
              say "     Platform: #{run_info[:platform]}", :white
              say "     Path: #{run_info[:path]}", :white
              say ''
            end
          else
            say 'No runs in this runset', :yellow
            say "Use 'serialbench runset add-run' to add runs", :white
          end
        rescue StandardError => e
          say "Error showing runset: #{e.message}", :red
          exit 1
        end
      end

      private

      def find_run(run_location, store)
        # Try as direct path first
        return Serialbench::Models::RunResult.load(run_location) if File.directory?(run_location)

        # Try as run name
        runs = store.find_runs(name: run_location)
        return runs.first unless runs.empty?

        # Try as partial path match
        runs = store.find_runs(limit: 100)
        runs.find { |run| run.directory.include?(run_location) }
      end

      def generate_runset_html(runset)
        <<~HTML
          <!DOCTYPE html>
          <html lang="en">
          <head>
              <meta charset="UTF-8">
              <meta name="viewport" content="width=device-width, initial-scale=1.0">
              <title>#{runset.name} - Serialbench Comparison</title>
              <style>
                  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
                  .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                  h1 { color: #333; border-bottom: 3px solid #007acc; padding-bottom: 10px; }
                  h2 { color: #555; margin-top: 30px; }
                  .runset-info { background: #f8f9fa; padding: 20px; border-radius: 6px; margin: 20px 0; }
                  .runs-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin: 20px 0; }
                  .run-card { background: #fff; border: 1px solid #ddd; border-radius: 6px; padding: 20px; }
                  .run-card h3 { margin-top: 0; color: #007acc; }
                  .run-path { font-family: monospace; background: #f1f1f1; padding: 5px 8px; border-radius: 3px; font-size: 0.9em; }
                  .timestamp { color: #666; font-size: 0.9em; }
                  .summary { background: #e8f4fd; padding: 15px; border-radius: 6px; margin: 20px 0; }
                  .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee; color: #666; text-align: center; }
              </style>
          </head>
          <body>
              <div class="container">
                  <h1>#{runset.name}</h1>

                  <div class="runset-info">
                      <h2>Runset Information</h2>
                      <p><strong>Name:</strong> #{runset.name}</p>
                      <p><strong>Description:</strong> #{runset.description || 'No description provided'}</p>
                      <p><strong>Created:</strong> #{runset.created_at}</p>
                      <p><strong>Updated:</strong> #{runset.updated_at}</p>
                      <p><strong>Total Runs:</strong> #{runset.result_count}</p>
                      <p><strong>Grouping:</strong> #{runset.grouping}</p>
                  </div>

                  <div class="summary">
                      <h2>Summary</h2>
                      <p>This runset contains <strong>#{runset.result_count}</strong> benchmark runs for comparison analysis.</p>
                      #{runset.environments.any? ? "<p><strong>Environments:</strong> #{runset.environments.join(', ')}</p>" : ''}
                      #{runset.formats.any? ? "<p><strong>Formats:</strong> #{runset.formats.join(', ')}</p>" : ''}
                      #{runset.serializers.any? ? "<p><strong>Serializers:</strong> #{runset.serializers.join(', ')}</p>" : ''}
                  </div>

                  <h2>Included Runs</h2>
                  <div class="runs-grid">
                      #{runset.results.map do |result|
                        <<~CARD
                          <div class="run-card">
                              <h3>#{result['name']}</h3>
                              <p class="run-path">#{result['path']}</p>
                              <p class="timestamp">Added: #{result['added_at']}</p>
                              #{result['tags'].any? ? "<p><strong>Tags:</strong> #{result['tags'].join(', ')}</p>" : ''}
                              #{result['notes'] ? "<p><strong>Notes:</strong> #{result['notes']}</p>" : ''}
                          </div>
                        CARD
                      end.join("\n")}
                  </div>

                  <div class="footer">
                      <p>Generated by Serialbench on #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}</p>
                      <p>Data available in <a href="data.json">data.json</a></p>
                  </div>
              </div>
          </body>
          </html>
        HTML
      end
    end
  end
end
