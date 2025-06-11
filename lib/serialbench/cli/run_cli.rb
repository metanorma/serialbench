# frozen_string_literal: true

require_relative 'base_cli'
require_relative '../benchmark_runner'
require_relative '../models/run_result'
require_relative '../models/report'

module Serialbench
  module Cli
    # CLI for managing individual benchmark runs
    class RunCli < BaseCli
      desc 'create [NAME]', 'Generate a run configuration file'
      long_desc <<~DESC
        Generate a configuration file for a benchmark run.

        NAME is optional - if not provided, a timestamped name will be generated.

        Examples:
          serialbench run create                    # Creates config with timestamp
          serialbench run create my-benchmark       # Creates config/runs/my-benchmark.yml
      DESC
      option :formats, type: :array, default: %w[xml json yaml toml],
                       desc: 'Formats to benchmark (xml, json, yaml, toml)'
      option :iterations, type: :numeric, default: 10,
                          desc: 'Number of benchmark iterations'
      option :warmup, type: :numeric, default: 3,
                      desc: 'Number of warmup iterations'
      option :data_sizes, type: :array, default: %w[small medium large],
                          desc: 'Data sizes to test (small, medium, large)'
      def create(name = nil)
        name ||= "run-#{generate_timestamp}"
        validate_name(name)

        config_dir = 'config/runs'
        FileUtils.mkdir_p(config_dir)

        config_file = File.join(config_dir, "#{name}.yml")

        if File.exist?(config_file)
          say "Configuration file already exists: #{config_file}", :yellow
          return unless yes?('Overwrite existing file? (y/n)')
        end

        config_content = generate_run_config(options)
        File.write(config_file, config_content)

        say "✅ Generated run configuration: #{config_file}", :green
        say 'Edit the file to customize benchmark settings', :cyan
      end

      desc 'execute CONFIG_FILE', 'Execute a benchmark run'
      long_desc <<~DESC
        Execute a benchmark run using the specified configuration file.

        Results will be saved to results/runs/ with platform-specific naming.

        Examples:
          serialbench run execute config/runs/my-benchmark.yml
          serialbench run execute config/runs/performance-test.yml
      DESC
      option :name, type: :string, desc: 'Optional name for the run (overrides config)'
      def execute(config_file)
        config = load_configuration(config_file)

        # Determine run name - provide a default if none is specified
        run_name = options[:name] || config['name'] || File.basename(config_file, '.yml') || 'benchmark-run'
        validate_name(run_name)

        say "🚀 Executing benchmark run: #{run_name}", :green
        say "Configuration: #{config_file}", :cyan

        begin
          # Create benchmark runner with config
          runner_options = {
            formats: (config['formats'] || %w[xml json yaml toml]).map(&:to_sym),
            iterations: config['iterations'] || 10,
            warmup: config['warmup'] || 3,
            config: config # Pass the full config to the runner
          }

          runner = Serialbench::BenchmarkRunner.new(**runner_options)

          # Run benchmarks
          results = runner.run_all_benchmarks

          # Create platform-specific directory name
          platform = Serialbench::Models::Platform.current_local
          directory_name = "#{run_name}-#{platform.platform_string}"

          # Save results using RunResult
          run_result = Serialbench::Models::RunResult.create(platform.platform_string, results)
          run_result.metadata[:config_file] = config_file
          run_result.metadata[:run_name] = run_name
          run_result.save

          say '✅ Benchmark run completed successfully!', :green
          say "Results saved to: results/runs/#{run_result.platform_string}", :cyan
        rescue StandardError => e
          say "Error executing benchmark run: #{e.message}", :red
          exit 1
        end
      end

      desc 'build-site RUN_PATH [OUTPUT_DIR]', 'Generate HTML site for a run'
      long_desc <<~DESC
        Generate an HTML site for a specific benchmark run.

        RUN_PATH should be the path to a run directory in results/runs/
        OUTPUT_DIR defaults to _site/

        Examples:
          serialbench run build-site results/runs/my-run-local-macos-arm64-ruby-3.3.8
          serialbench run build-site results/runs/performance-test-docker-alpine-arm64-ruby-3.3 output/
      DESC
      def build_site(run_path, output_dir = '_site')
        unless File.directory?(run_path)
          say "Run directory not found: #{run_path}", :red
          exit 1
        end

        say "🏗️  Generating HTML site for run: #{File.basename(run_path)}", :green

        begin
          # Use SiteGenerator to generate the site
          generator = Serialbench::SiteGenerator.generate_for_result(run_path, output_dir)

          say '✅ HTML site generated successfully!', :green
          say "Site location: #{output_dir}", :cyan
          say "Open: #{File.join(output_dir, 'index.html')}", :white
        rescue StandardError => e
          say "Error generating site: #{e.message}", :red
          say "Details: #{e.backtrace.first(3).join("\n")}", :red if options[:verbose]
          exit 1
        end
      end

      desc 'list', 'List all available runs'
      long_desc <<~DESC
        List all benchmark runs in the results/runs/ directory.

        Shows run names, platforms, and timestamps.
      DESC
      option :limit, type: :numeric, default: 20, desc: 'Maximum number of runs to show'
      option :tags, type: :array, desc: 'Filter by tags (e.g., docker, ruby-3.3)'
      def list
        ensure_results_directory

        begin
          store = Serialbench::Models::ResultStore.default
          runs = if options[:tags]
                   store.find_runs(tags: options[:tags], limit: options[:limit])
                 else
                   store.latest_runs(options[:limit])
                 end

          if runs.empty?
            say 'No runs found', :yellow
            return
          end

          say 'Available Runs:', :green
          say '=' * 50, :green

          runs.each do |run|
            say "📊 #{run.name}", :cyan
            say "   Platform: #{run.platform.platform_string}", :white
            say "   Created: #{run.metadata[:timestamp]}", :white
            say "   Path: #{run.directory}", :white
            say ''
          end
        rescue StandardError => e
          say "Error listing runs: #{e.message}", :red
          exit 1
        end
      end

      private

      def generate_run_config(options)
        <<~YAML
          # Serialbench Run Configuration
          # Generated on #{Time.now.iso8601}

          # Run name (optional - will use filename if not specified)
          # name: my-benchmark-run

          # Formats to benchmark
          formats:
          #{options[:formats].map { |f| "  - #{f}" }.join("\n")}

          # Number of benchmark iterations
          iterations: #{options[:iterations]}

          # Number of warmup iterations
          warmup: #{options[:warmup]}

          # Data sizes to test
          data_sizes:
          #{options[:data_sizes].map { |s| "  - #{s}" }.join("\n")}

          # Output format options
          output_format: all  # all, json, yaml, html

          # Memory profiling (optional)
          # memory_profiling: true

          # Specific operations to run (optional - defaults to all)
          # operations:
          #   - parsing
          #   - generation
          #   - streaming
          #   - memory
        YAML
      end
    end
  end
end
