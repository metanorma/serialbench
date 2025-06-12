# frozen_string_literal: true

require 'ostruct'
require_relative 'base_cli'
require_relative '../benchmark_runner'
require_relative '../models/result'
require_relative '../models/benchmark_config'
require_relative '../models/environment_config'
require_relative '../models/platform'

module Serialbench
  module Cli
    # CLI for managing individual benchmark runs
    class BenchmarkCli < BaseCli
      desc 'create [NAME]', 'Generate a run configuration file'
      long_desc <<~DESC
        Generate a configuration file for a benchmark run.

        NAME is optional - if not provided, a timestamped name will be generated.

        Examples:
          serialbench benchmark create                    # Creates config with timestamp
          serialbench benchmark create my-benchmark       # Creates config/runs/my-benchmark.yml
      DESC
      option :formats, type: :array, default: %w[xml json yaml toml],
                       desc: 'Formats to benchmark (xml, json, yaml, toml)'
      option :warmup, type: :numeric, default: 3,
                      desc: 'Number of warmup iterations'
      option :data_sizes, type: :array, default: %w[small medium large],
                          desc: 'Data sizes to test (small, medium, large)'
      def create(name = nil)
        raise 'Run name cannot be empty' if name&.strip&.empty?

        validate_name(name)

        config_dir = 'config/runs'
        FileUtils.mkdir_p(config_dir)

        benchmark_config_path = File.join(config_dir, "#{name}.yml")

        if File.exist?(benchmark_config_path)
          say "Configuration file already exists: #{benchmark_config_path}", :yellow
          return unless yes?('Overwrite existing file? (y/n)')
        end

        benchmark_config = Models::BenchmarkConfig.new(
          formats: options[:formats],
          warmup: options[:warmup],
          data_sizes: options[:data_sizes]
        )

        benchmark_config.to_file(benchmark_config_path)

        say "✅ Generated run configuration: #{benchmark_config_path}", :green
        say 'Edit the file to customize benchmark settings', :cyan
      end

      desc 'execute ENVIRONMENT_CONFIG_PATH BENCHMARK_CONFIG_PATH', 'Execute a benchmark run'
      long_desc <<~DESC
        Execute a benchmark run using the specified environment and configuration file.

        ENVIRONMENT must be the name of an existing environment (from environments/ directory).
        BENCHMARK_CONFIG_PATH is the path to the benchmark configuration file.

        Results will be saved to results/runs/ with platform-specific naming based on the environment.

        Examples:
          serialbench benchmark execute environments/local-dev.yml config/short.yml
          serialbench benchmark execute environments/docker-alpine.yml config/full.yml
      DESC
      def execute(environment_config_path, benchmark_config_path)
        environment = load_environment_config(environment_config_path)
        config = load_benchmark_config(benchmark_config_path)

        say '🚀 Executing benchmark run', :green
        say "Environment: #{environment.name} (#{environment.kind})", :cyan
        say "Configuration: #{benchmark_config_path}", :cyan

        begin
          # Execute benchmark based on environment type
          case environment.kind
          when 'local'
            execute_local_benchmark(environment, config, benchmark_config_path)
          when 'docker'
            execute_docker_benchmark(environment, config, benchmark_config_path)
          when 'asdf'
            execute_asdf_benchmark(environment, config, benchmark_config_path)
          else
            raise "Unsupported environment type: #{environment.kind}"
          end
        rescue StandardError => e
          say "❌ Error executing benchmark run: #{e.message}", :red
          exit 1
        end
      end

      desc '_docker_execute ENVIRONMENT_CONFIG_PATH BENCHMARK_CONFIG_PATH', '(Private) Execute a benchmark run'
      long_desc <<~DESC
        For docker used internally by the CLI.

        Examples:
          serialbench benchmark _docker_execute /app/environment.yml /app/benchmark_config.yml
          serialbench benchmark _docker_execute /app/environment.yml /app/benchmark_config.yml
      DESC
      option :result_dir, type: :string, default: 'results/runs',
                          desc: 'Directory to save benchmark results'
      def _docker_execute(environment_config_path, benchmark_config_path)
        environment_config = load_environment_config(environment_config_path)
        benchmark_config = load_benchmark_config(benchmark_config_path)

        say '🚀 Executing benchmark run', :green
        say "Environment: #{environment_config_path} (#{environment_config.kind})", :cyan
        say "Configuration: #{benchmark_config_path}", :cyan

        runner = Serialbench::BenchmarkRunner.new(
          environment_config: environment_config,
          benchmark_config: benchmark_config
        )

        # Run benchmarks
        results = runner.run_all_benchmarks

        platform = Serialbench::Models::Platform.current_local

        metadata = Models::RunMetadata.new(
          benchmark_config_path: benchmark_config_path,
          environment_config_path: environment_config_path,
          tags: [
            'docker',
            platform.os,
            platform.arch,
            "ruby-#{environment_config.ruby_build_tag}"
          ]
        )
        # Create results directory
        result_dir = options[:result_dir]
        FileUtils.mkdir_p(result_dir)

        # Save results to single YAML file with platform and metadata merged in
        results_model = Models::Result.new(
          platform: platform,
          metadata: metadata,
          environment_config: environment_config,
          benchmark_config: benchmark_config,
          benchmark_result: results
        )

        # Restore YAML to use Psych for output, otherwise lutaml-model's to_yaml
        # will have no output
        Object.const_set(:YAML, Psych)

        results_file = File.join(result_dir, 'results.yaml')
        results_model.to_file(results_file)

        say '✅ Local benchmark completed successfully!', :green
        say 'Results saved.', :cyan
      rescue StandardError => e
        say "❌ Local benchmark failed: #{e.message}", :red
        say "Details: #{e.backtrace.first(3).join("\n")}", :white if options[:verbose]
        raise e
      end

      desc 'build-site RUN_PATH [OUTPUT_DIR]', 'Generate HTML site for a run'
      long_desc <<~DESC
        Generate an HTML site for a specific benchmark run.

        RUN_PATH should be the path to a run directory in results/runs/
        OUTPUT_DIR defaults to _site/

        Examples:
          serialbench benchmark build-site results/runs/my-run-local-macos-arm64-ruby-3.3.8
          serialbench benchmark build-site results/runs/performance-test-docker-alpine-arm64-ruby-3.3
      DESC
      option :output_dir, type: :string, default: '_site', desc: 'Output directory for generated site'
      def build_site(result_path)
        unless Dir.exist?(result_path)
          say "Result directory not found: #{result_path}", :red
          say "Please create a result first using 'serialbench benchmark create'", :white
          exit 1
        end

        result = Serialbench::Models::Result.load(result_path)

        if result.nil?
          say "Result '#{result_path}' not found", :yellow
          say "Use 'serialbench benchmark add-result' to add a result first", :white
          return
        end

        say "🏗️  Generating HTML site for result: #{result_path}", :green

        # Use the unified site generator for results
        Serialbench::SiteGenerator.generate_for_result(result, options[:output_dir])

        say '✅ HTML site generated successfully!', :green
        say "Site location: #{options[:output_dir]}", :cyan
        say "Open: #{File.join(options[:output_dir], 'index.html')}", :white
      rescue StandardError => e
        say "Error generating site: #{e.message}", :red
        say "Details: #{e.backtrace.first(3).join("\n")}", :red if options[:verbose]
        exit 1
      end

      desc 'list', 'List all available runs'
      long_desc <<~DESC
        List all benchmark runs in the results/runs/ directory.

        Shows benchmark run names, platforms, and timestamps.
      DESC
      option :tags, type: :array, desc: 'Filter by tags (e.g., docker, ruby-3.3)'
      def list
        store = Serialbench::Models::ResultStore.default
        runs = if options[:tags]
                 store.find_runs(tags: options[:tags])
               else
                 store.find_runs
               end

        if runs.empty?
          say 'No runs found', :yellow
          return
        end

        say 'Available Runs:', :green
        say '=' * 50, :green

        runs.each do |run|
          say '📊 Run:', :cyan
          say "   Created: #{run.metadata.created_at}", :white
          say "   Platform: #{run.platform.platform_string} (os: #{run.platform.os}, arch: #{run.platform.arch})",
              :white
          say "   Environment config: #{run.metadata.environment_config_path}", :white
          say "   Benchmark config: #{run.metadata.benchmark_config_path}", :white
          say "   Environment: #{run.environment_config.name} (#{run.environment_config.kind})", :white
          say "   Tags: [#{run.metadata.tags.join(', ')}]", :white
          say ''
        end
      rescue StandardError => e
        say "Error listing runs: #{e.message}", :red
        exit 1
      end

      private

      def show_execute_usage_and_exit
        say '❌ Error: Environment and config file arguments are required.', :red
        say ''
        say 'Usage:', :white
        say '  serialbench benchmark execute ENVIRONMENT_CONFIG_PATH BENCHMARK_CONFIG_PATH', :cyan
        say ''
        say 'Arguments:', :white
        say '  ENVIRONMENT_CONFIG_PATH    Path to environment configuration file', :white
        say '  BENCHMARK_CONFIG_PATH      Path to benchmark configuration file', :white
        say ''
        say 'Examples:', :white
        say '  serialbench benchmark execute config/environments/local-dev.yml config/short.yml', :cyan
        say '  serialbench benchmark execute config/environments/docker-alpine.yml config/full.yml', :cyan
        exit 1
      end

      def load_environment_config(environment_config_path)
        unless File.exist?(environment_config_path)
          say "❌ Environment not found: #{environment_config_path}", :red
          exit 1
        end

        Models::EnvironmentConfig.from_file(environment_config_path)
      rescue StandardError => e
        say "❌ Failed to load environment: #{e.message}", :red
        say "Environment file: #{environment_config_path}", :white
        exit 1
      end

      def load_benchmark_config(benchmark_config_path)
        unless File.exist?(benchmark_config_path)
          say "❌ Benchmark config not found: #{benchmark_config_path}", :red
          exit 1
        end

        Models::BenchmarkConfig.from_file(benchmark_config_path)
      rescue StandardError => e
        say "❌ Failed to load benchmark config: #{e.message}", :red
        say "Benchmark config file: #{benchmark_config_path}", :white
        exit 1
      end

      # def execute_local_benchmark(environment, config, benchmark_config_path)
      #   say '🏠 Executing local benchmark', :green

      #   # Create benchmark runner with config
      #   runner_options = {
      #     formats: (config['formats'] || %w[xml json yaml toml]).map(&:to_sym),
      #     iterations: config['iterations'] || 10,
      #     warmup: config['warmup'] || 3,
      #     config: config
      #   }

      #   runner = Serialbench::BenchmarkRunner.new(**runner_options)

      #   # Run benchmarks
      #   say "Running benchmarks with #{runner_options[:iterations]} iterations...", :white
      #   results = runner.run_all_benchmarks

      #   # Create platform-specific directory name using environment's ruby_build_tag
      #   require_relative '../models/platform'
      #   platform = Serialbench::Models::Platform.current_local
      #   platform_string = "local-#{platform.os}-#{platform.arch}-ruby-#{environment['ruby_build_tag']}"

      #   # Create results directory
      #   result_dir = "results/runs/#{environment['name']}"
      #   FileUtils.mkdir_p(result_dir)

      #   # Save results to single YAML file with platform and metadata merged in
      #   results_file = File.join(result_dir, 'results.yaml')
      #   full_results = {
      #     'platform' => {
      #       'platform_string' => platform_string,
      #       'os' => platform.os,
      #       'arch' => platform.arch
      #     },
      #     'metadata' => {
      #       'environment_name' => environment['name'],
      #       'benchmark_config' => benchmark_config_path,
      #       'created_at' => Time.now.iso8601,
      #       'tags' => ['local', platform.os, platform.arch, "ruby-#{environment['ruby_build_tag']}"]
      #     },
      #     'environment' => {
      #       'name' => environment['name'],
      #       'type' => environment.kind,
      #       'ruby_build_tag' => environment['ruby_build_tag'],
      #       'created_at' => Time.now.iso8601
      #     },
      #     'config' => {
      #       'benchmark_config' => benchmark_config_path,
      #       'formats' => config['formats'],
      #       'iterations' => config['iterations'],
      #       'data_sizes' => config['data_sizes']
      #     },
      #     'results' => results
      #   }

      #   File.write(results_file, full_results.to_yaml)

      #   say '✅ Local benchmark completed successfully!', :green
      #   say "Results saved to: #{result_dir}", :cyan
      #   say "Generate site: serialbench benchmark build-site #{result_dir}", :white
      # rescue StandardError => e
      #   say "❌ Local benchmark failed: #{e.message}", :red
      #   say "Details: #{e.backtrace.first(3).join("\n")}", :white if options[:verbose]
      #   raise e
      # end

      def execute_asdf_benchmark(environment, config, benchmark_config_path)
        say '🔧 Executing ASDF benchmark', :green

        # Use the ASDF runner to execute the benchmark
        require_relative '../asdf_runner'

        # Create a config object that AsdfRunner expects
        asdf_config = environment.merge({
                                          'benchmark_config' => benchmark_config_path
                                        })

        runner = Serialbench::AsdfRunner.new(asdf_config)

        say "Installing Ruby #{environment['ruby_build_tag']} via ASDF...", :white
        runner.prepare
        runner.benchmark

        say '✅ ASDF benchmark completed successfully!', :green
        say "Results saved to: results/runs/#{environment['name']}", :cyan
        say "Generate site: serialbench benchmark build-site results/runs/#{environment['name']}", :white
      rescue StandardError => e
        say "❌ ASDF benchmark failed: #{e.message}", :red
        say "Details: #{e.backtrace.first(3).join("\n")}", :white if options[:verbose]
        raise e
      end
    end
  end
end
