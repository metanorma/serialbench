# frozen_string_literal: true

require 'thor'
require 'yaml'
require 'fileutils'
require_relative '../models/environment_config'
require_relative '../models/benchmark_config'

module Serialbench
  module Cli
    # Environment management CLI
    class EnvironmentCli < BaseCli
      desc 'new NAME KIND RUBY_BUILD_TAG', 'Create a new environment configuration'
      long_desc <<~DESC
        Create a new environment configuration file.

        NAME: Unique name for the environment
        KIND: Environment kind (docker, asdf, local)
        RUBY_BUILD_TAG: Ruby version/tag to use (from ruby-build definitions)

        Examples:
          serialbench environment new docker-ruby33 docker 3.3.2 --docker_image ruby:3.3-alpine --dockerfile Dockerfile --dir config/environments
          serialbench environment new asdf-ruby32 asdf 3.2.4
          serialbench environment new local-dev local 3.1.0

        This creates a configuration file at environments/NAME.yml
      DESC
      option :dir, type: :string, default: 'config/environments', desc: 'Directory to create environment config in'
      option :docker_image, type: :string, default: 'ruby:3.3-alpine',
                            desc: 'Default Docker image for docker environments'
      option :dockerfile, type: :string, default: 'Dockerfile', desc: 'Default Dockerfile for docker environments'
      def new(name, kind, ruby_build_tag)
        validate_environment_name!(name)

        config_path = File.join(options[:dir], "#{name}.yml")

        if File.exist?(config_path)
          say "Environment '#{name}' already exists at #{config_path}", :yellow
          return unless yes?('Overwrite existing environment? (y/n)')
        end

        FileUtils.mkdir_p('config/environments')

        kind_config = case kind
                      when 'docker'
                        raise unless options[:docker_image] && options[:dockerfile]

                        Models::EnvironmentConfig.new(
                          name: name,
                          type: kind,
                          ruby_build_tag: ruby_build_tag,
                          docker: Models::DockerEnvConfig.new(
                            image: options[:docker_image],
                            dockerfile: options[:dockerfile]
                          ),
                          description: "Docker environment for Ruby #{ruby_build_tag} benchmarks"
                        )
                      when 'asdf'
                        Models::EnvironmentConfig.new(
                          name: name,
                          type: kind,
                          ruby_build_tag: ruby_build_tag,
                          asdf: Models::AsdfEnvConfig.new(auto_install: true),
                          description: "ASDF environment for Ruby #{ruby_build_tag} benchmarks"
                        )
                      end
        File.write(config_path, kind_config.to_yaml)

        say "✅ Created environment template: #{config_path}", :green

        # Show ruby-build tag suggestion for local environments
        show_ruby_build_suggestion if kind == 'local'

        say ''
        say 'Next steps:', :white
        say "1. Edit #{config_path} to confirm/change configuration", :cyan
        say "2. Validate: serialbench environment validate #{config_path}", :cyan
        say "3. Run benchmark: serialbench benchmark execute #{config_path} config/short.yml", :cyan
      end

      desc 'execute ENVIRONMENT_CONFIG BENCHMARK_CONFIG RESULT_PATH', 'Execute benchmark in environment'
      long_desc <<~DESC
        Execute a benchmark run in the specified environment.

        ENVIRONMENT_CONFIG: Path to environment configuration file
        BENCHMARK_CONFIG: Path to benchmark configuration file
        RESULT_PATH: Path to create result output at

        Examples:
          serialbench environment execute config/environments/docker-ruby33.yml config/xml-only.yml results/runs/xml-perf-test
          serialbench environment execute environments/custom.yml config/full.yml results/runs/my-test
      DESC
      def execute(environment_path, benchmark_config_path, result_dir)
        benchmark_config = load_benchmark_config(benchmark_config_path)
        environment_config = load_environment_config(environment_path)

        say "🚀 Running benchmark '#{benchmark_config_path}' in environment '#{environment_config.name}'...", :green

        FileUtils.mkdir_p(result_dir)
        say "Results will be saved to: #{result_dir}", :cyan

        runner = create_environment_runner(environment_config, environment_path)
        runner.run_benchmark(benchmark_config, benchmark_config_path, result_dir)

        say '✅ Benchmark completed successfully!', :green
        say "Results saved to: #{result_dir}", :cyan
      rescue StandardError => e
        say "❌ Benchmark failed: #{e.message}", :red
        exit 1
      end

      desc 'prepare ENVIRONMENT_CONFIG', 'Prepare environment for benchmarking'
      long_desc <<~DESC
        Prepare the specified environment for benchmark execution.
        This installs dependencies, sets up runtime environments, etc.

        ENVIRONMENT_CONFIG: Path to environment configuration file

        Examples:
          serialbench environment prepare config/environments/docker-ruby33.yml
          serialbench environment prepare environments/custom.yml
      DESC
      def prepare(environment_config_path)
        environment_config = load_environment_config(environment_config_path)

        say "🔧 Preparing environment '#{environment_config.name}'...", :green

        runner = create_environment_runner(environment_config, environment_config_path)
        runner.prepare

        say '✅ Environment prepared successfully!', :green
      rescue StandardError => e
        say "❌ Environment preparation failed: #{e.message}", :red
        say e.backtrace.join("\n"), :red
        exit 1
      end

      private

      def load_benchmark_config(benchmark_config_path)
        unless File.exist?(benchmark_config_path)
          say "❌ Benchmark configuration file not found: #{benchmark_config_path}", :red
          exit 1
        end

        Models::BenchmarkConfig.from_yaml(IO.read(benchmark_config_path))
      rescue StandardError => e
        say "❌ Failed to load benchmark config: #{e.message}", :red
        exit 1
      end

      def load_environment_config(environment_config_path)
        unless File.exist?(environment_config_path)
          say "❌ Environment not found: #{environment_config_path}", :red
          exit 1
        end

        Models::EnvironmentConfig.from_yaml(IO.read(environment_config_path))
      rescue StandardError => e
        say "❌ Failed to load environment config: #{e.message}", :red
        exit 1
      end

      def create_environment_runner(environment_config, environment_config_path)
        case environment_config.kind
        when 'docker'
          require_relative '../runners/docker_runner'
          Runners::DockerRunner.new(environment_config, environment_config_path)
        when 'asdf'
          require_relative '../runners/asdf_runner'
          Runners::AsdfRunner.new(environment_config, environment_config_path)
        when 'local'
          require_relative '../runners/local_runner'
          Runners::LocalRunner.new(environment_config, environment_config_path)
        else
          raise "Unknown environment type: #{environment_config.kind}"
        end
      end
    end
  end
end
