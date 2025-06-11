# frozen_string_literal: true

require 'thor'
require 'yaml'
require 'fileutils'

module Serialbench
  module Cli
    # Environment management CLI
    class EnvironmentCli < BaseCli
      desc 'new NAME TYPE', 'Create a new environment configuration'
      long_desc <<~DESC
        Create a new environment configuration file.

        NAME: Unique name for the environment
        TYPE: Environment type (docker, asdf, local)

        Examples:
          serialbench environment new docker-ruby33 docker
          serialbench environment new asdf-ruby32 asdf
          serialbench environment new local-dev local

        This creates a configuration file at environments/NAME.yml
      DESC
      def new(name, type)
        validate_environment_name!(name)

        config_path = "environments/#{name}.yml"

        if File.exist?(config_path)
          say "Environment '#{name}' already exists at #{config_path}", :yellow
          return unless yes?('Overwrite existing environment? (y/n)')
        end

        FileUtils.mkdir_p('environments')

        config = generate_environment_config(name, type)
        File.write(config_path, config.to_yaml)

        say "✅ Created environment '#{name}' at #{config_path}", :green
        say 'Edit the configuration file to customize settings', :cyan
      end

      desc 'execute NAME RESULT_NAME BENCHMARK_CONFIG', 'Execute benchmark in environment'
      long_desc <<~DESC
        Execute a benchmark run in the specified environment.

        NAME: Environment name (from environments/ directory) or path to config file
        RESULT_NAME: Custom name for the result output
        BENCHMARK_CONFIG: Path to benchmark configuration file

        Examples:
          serialbench environment execute docker-ruby33 xml-perf-test config/xml-only.yml
          serialbench environment execute environments/custom.yml my-test config/full.yml

        Results are stored in results/RESULT_NAME/
      DESC
      def execute(name, result_name, benchmark_config)
        validate_result_name!(result_name)
        validate_benchmark_config!(benchmark_config)

        environment = load_environment(name)

        say "🚀 Running benchmark '#{result_name}' in environment '#{environment['name']}'...", :green

        result_dir = "results/#{result_name}"
        FileUtils.mkdir_p(result_dir)

        begin
          runner = create_environment_runner(environment)
          runner.run_benchmark(benchmark_config, result_dir)

          say '✅ Benchmark completed successfully!', :green
          say "Results saved to: #{result_dir}", :cyan
        rescue StandardError => e
          say "❌ Benchmark failed: #{e.message}", :red
          exit 1
        end
      end

      desc 'batch ENVIRONMENTS RESULT_PREFIX BENCHMARK_CONFIG', 'Run benchmark across multiple individual environments'
      long_desc <<~DESC
        Execute a benchmark across multiple individual environment configurations.
        Each environment is a separate .yml file in the environments/ directory.

        ENVIRONMENTS: Comma-separated list of environment names
        RESULT_PREFIX: Prefix for result names (will append environment name)
        BENCHMARK_CONFIG: Path to benchmark configuration file

        Examples:
          serialbench environment batch docker-ruby33,asdf-ruby32 cross-env config/full.yml

        This creates results like:
          results/cross-env-docker-ruby33/
          results/cross-env-asdf-ruby32/
      DESC
      def batch(environments, result_prefix, benchmark_config)
        validate_benchmark_config!(benchmark_config)

        env_names = environments.split(',').map(&:strip)

        if env_names.empty?
          say '❌ No environments specified', :red
          exit 1
        end

        say "🚀 Running benchmark across #{env_names.length} environments...", :green

        results = []
        env_names.each do |env_name|
          result_name = "#{result_prefix}-#{env_name}"

          say "Running in environment: #{env_name}", :yellow

          begin
            execute(env_name, result_name, benchmark_config)
            results << result_name
          rescue SystemExit
            say "⚠️  Skipping failed environment: #{env_name}", :yellow
            next
          end
        end

        if results.empty?
          say '❌ All environments failed', :red
          exit 1
        end

        say '✅ Batch benchmark completed!', :green
        say "Successful results: #{results.join(', ')}", :cyan
        say 'Consider creating a resultset to aggregate these results:', :white
        say "  serialbench runset new #{result_prefix}-comparison", :white
        results.each do |result|
          say "  serialbench runset add-result #{result_prefix}-comparison #{result}", :white
        end
      end

      desc 'multi-prepare RUNTIME', 'Prepare multi-version runtime environment'
      long_desc <<~DESC
        Prepare a runtime environment that supports multiple Ruby versions.
        Uses a single configuration file that defines multiple versions.

        RUNTIME can be:
        - docker: Build Docker images for all specified Ruby versions and variants
        - asdf: Install Ruby versions via ASDF

        Examples:
          serialbench environment multi-prepare docker --config=serialbench-docker.yml
          serialbench environment multi-prepare asdf --config=serialbench-asdf.yml
      DESC
      option :config, type: :string, required: true,
                      desc: 'Multi-environment configuration file path'
      def multi_prepare(runtime)
        say "🚀 Preparing #{runtime} multi-version environment...", :green

        begin
          config = load_and_validate_multi_config(options[:config])

          unless config.runtime == runtime
            say "Error: Configuration runtime (#{config.runtime}) doesn't match specified runtime (#{runtime})", :red
            exit 1
          end

          runner = create_multi_runner(config)
          runner.prepare

          say "✅ #{runtime.capitalize} multi-version environment prepared successfully!", :green
        rescue StandardError => e
          say "Error preparing #{runtime} environment: #{e.message}", :red
          exit 1
        end
      end

      desc 'multi-benchmark RUNTIME', 'Run benchmarks across multiple Ruby versions'
      long_desc <<~DESC
        Run benchmarks across multiple Ruby versions in the specified runtime.
        Uses a single configuration file that defines multiple versions.

        RUNTIME can be:
        - docker: Run benchmarks in Docker containers for each Ruby version
        - asdf: Run benchmarks using local ASDF Ruby versions

        The environment must be prepared first using 'multi-prepare'.

        Examples:
          serialbench environment multi-benchmark docker --config=serialbench-docker.yml
          serialbench environment multi-benchmark asdf --config=serialbench-asdf.yml
      DESC
      option :config, type: :string, required: true,
                      desc: 'Multi-environment configuration file path'
      def multi_benchmark(runtime)
        say "🏃 Running benchmarks across multiple Ruby versions in #{runtime}...", :green

        begin
          config = load_and_validate_multi_config(options[:config])

          unless config.runtime == runtime
            say "Error: Configuration runtime (#{config.runtime}) doesn't match specified runtime (#{runtime})", :red
            exit 1
          end

          runner = create_multi_runner(config)
          runner.benchmark

          say '🎉 Multi-version benchmarks completed successfully!', :green
        rescue StandardError => e
          say "Error running benchmarks: #{e.message}", :red
          exit 1
        end
      end

      desc 'multi-execute RUNTIME', 'Prepare and run multi-version benchmarks in one command'
      long_desc <<~DESC
        Prepare the environment and run benchmarks across multiple Ruby versions.
        This is equivalent to running 'multi-prepare' followed by 'multi-benchmark'.

        RUNTIME can be:
        - docker: Build Docker images and run benchmarks for all Ruby versions
        - asdf: Install Ruby versions and run benchmarks for all versions

        Examples:
          serialbench environment multi-execute docker --config=serialbench-docker.yml
          serialbench environment multi-execute asdf --config=serialbench-asdf.yml
      DESC
      option :config, type: :string, required: true,
                      desc: 'Multi-environment configuration file path'
      def multi_execute(runtime)
        say "🚀 Running complete multi-version benchmark suite in #{runtime}...", :green

        begin
          config = load_and_validate_multi_config(options[:config])

          unless config.runtime == runtime
            say "Error: Configuration runtime (#{config.runtime}) doesn't match specified runtime (#{runtime})", :red
            exit 1
          end

          runner = create_multi_runner(config)

          # Prepare environment
          say 'Phase 1: Preparing multi-version environment...', :yellow
          runner.prepare

          # Run benchmarks
          say 'Phase 2: Running benchmarks across all versions...', :yellow
          runner.benchmark

          say '🎉 Complete multi-version benchmark suite finished successfully!', :green
        rescue StandardError => e
          say "Error running benchmark suite: #{e.message}", :red
          exit 1
        end
      end

      desc 'prepare NAME', 'Prepare environment for benchmarking'
      long_desc <<~DESC
        Prepare the specified environment for benchmark execution.
        This installs dependencies, sets up runtime environments, etc.

        NAME: Environment name or path to config file

        Examples:
          serialbench environment prepare docker-ruby33
          serialbench environment prepare environments/custom.yml
      DESC
      def prepare(name)
        environment = load_environment(name)

        say "🔧 Preparing environment '#{environment['name']}'...", :green

        begin
          runner = create_environment_runner(environment)
          runner.prepare

          say '✅ Environment prepared successfully!', :green
        rescue StandardError => e
          say "❌ Environment preparation failed: #{e.message}", :red
          exit 1
        end
      end

      desc 'validate NAME', 'Validate environment configuration'
      long_desc <<~DESC
        Validate an environment configuration file.

        NAME: Environment name or path to config file

        Examples:
          serialbench environment validate docker-ruby33
          serialbench environment validate environments/custom.yml
      DESC
      def validate(name)
        say '🔍 Validating environment configuration...', :green

        begin
          environment = load_environment(name)

          # Validate required fields
          validate_environment_config!(environment)

          say '✅ Environment configuration is valid!', :green
          say "Name: #{environment['name']}", :cyan
          say "Type: #{environment['type']}", :cyan

          case environment['type']
          when 'docker'
            say "Ruby versions: #{environment['ruby_versions'].join(', ')}", :cyan
            say "Image variants: #{environment['image_variants'].join(', ')}", :cyan if environment['image_variants']
          when 'asdf'
            say "Ruby versions: #{environment['ruby_versions'].join(', ')}", :cyan
            say "Auto-install: #{environment['auto_install']}", :cyan
          when 'local'
            say "Ruby path: #{environment['ruby_path'] || 'system default'}", :cyan
          end
        rescue StandardError => e
          say "❌ Validation failed: #{e.message}", :red
          exit 1
        end
      end

      desc 'list', 'List all available environments'
      def list
        environments_dir = 'environments'

        unless Dir.exist?(environments_dir)
          say 'No environments directory found. Create one with:', :yellow
          say '  serialbench environment new my-env docker', :white
          return
        end

        env_files = Dir.glob("#{environments_dir}/*.yml")

        if env_files.empty?
          say "No environments found in #{environments_dir}/", :yellow
          say 'Create one with:', :white
          say '  serialbench environment new my-env docker', :white
          return
        end

        say 'Available environments:', :green
        env_files.each do |file|
          name = File.basename(file, '.yml')
          begin
            config = YAML.load_file(file)
            type = config['type'] || 'unknown'
            say "  #{name} (#{type})", :cyan
          rescue StandardError
            say "  #{name} (invalid config)", :red
          end
        end
      end

      private

      def validate_environment_name!(name)
        if name.nil? || name.strip.empty?
          say '❌ Environment name cannot be empty', :red
          exit 1
        end

        return unless name.include?('/')

        say "❌ Environment name cannot contain '/' characters", :red
        exit 1
      end

      def validate_result_name!(name)
        if name.nil? || name.strip.empty?
          say '❌ Result name cannot be empty', :red
          exit 1
        end

        return unless name.include?('/')

        say "❌ Result name cannot contain '/' characters", :red
        exit 1
      end

      def validate_benchmark_config!(config_path)
        return if File.exist?(config_path)

        say "❌ Benchmark configuration file not found: #{config_path}", :red
        exit 1
      end

      def load_environment(name_or_path)
        config_path = if name_or_path.end_with?('.yml') || name_or_path.include?('/')
                        name_or_path
                      else
                        "environments/#{name_or_path}.yml"
                      end

        unless File.exist?(config_path)
          say "❌ Environment not found: #{config_path}", :red
          exit 1
        end

        begin
          YAML.load_file(config_path)
        rescue StandardError => e
          say "❌ Failed to load environment config: #{e.message}", :red
          exit 1
        end
      end

      def validate_environment_config!(config)
        required_fields = %w[name type]

        required_fields.each do |field|
          raise "Missing required field: #{field}" unless config[field]
        end

        unless %w[docker asdf local].include?(config['type'])
          raise "Invalid environment type: #{config['type']}. Must be docker, asdf, or local"
        end

        case config['type']
        when 'docker'
          unless config['ruby_versions']&.is_a?(Array) && !config['ruby_versions'].empty?
            raise 'Docker environments must specify ruby_versions array'
          end
        when 'asdf'
          unless config['ruby_versions']&.is_a?(Array) && !config['ruby_versions'].empty?
            raise 'ASDF environments must specify ruby_versions array'
          end
        end
      end

      def generate_environment_config(name, type)
        base_config = {
          'name' => name,
          'type' => type,
          'created_at' => Time.now.iso8601
        }

        case type
        when 'docker'
          base_config.merge({
                              'ruby_versions' => ['3.2', '3.3'],
                              'image_variants' => %w[slim alpine],
                              'build_args' => {},
                              'run_args' => {}
                            })
        when 'asdf'
          base_config.merge({
                              'ruby_versions' => ['3.2.8', '3.3.8'],
                              'auto_install' => true,
                              'global_gems' => []
                            })
        when 'local'
          base_config.merge({
                              'ruby_path' => nil, # Use system default
                              'bundle_path' => nil,
                              'env_vars' => {}
                            })
        else
          raise "Unknown environment type: #{type}"
        end
      end

      def create_environment_runner(environment)
        case environment['type']
        when 'docker'
          require_relative '../docker_runner'
          DockerRunner.new(environment)
        when 'asdf'
          require_relative '../asdf_runner'
          AsdfRunner.new(environment)
        when 'local'
          require_relative '../local_runner'
          LocalRunner.new(environment)
        else
          raise "Unknown environment type: #{environment['type']}"
        end
      end

      def load_and_validate_multi_config(config_path)
        require_relative '../config_manager'
        ConfigManager.load_and_validate(config_path)
      rescue ConfigManager::ConfigurationError => e
        say "Configuration error: #{e.message}", :red
        exit 1
      end

      def create_multi_runner(config)
        case config.runtime
        when 'docker'
          require_relative '../docker_runner'
          DockerRunner.new(config)
        when 'asdf'
          require_relative '../asdf_runner'
          AsdfRunner.new(config)
        else
          raise "Unknown runtime: #{config.runtime}"
        end
      end
    end
  end
end
