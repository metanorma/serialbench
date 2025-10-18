# frozen_string_literal: true

require 'thor'
require_relative 'cli/base_cli'
require_relative 'cli/environment_cli'
require_relative 'cli/benchmark_cli'
require_relative 'cli/resultset_cli'
require_relative 'cli/ruby_build_cli'

module Serialbench
  # Main CLI entry point for the new object-oriented command structure
  class CLI < Serialbench::Cli::BaseCli
    desc 'environment SUBCOMMAND', 'Manage benchmark environments'
    subcommand 'environment', Serialbench::Cli::EnvironmentCli

    desc 'benchmark SUBCOMMAND', 'Manage individual benchmark runs'
    subcommand 'benchmark', Serialbench::Cli::BenchmarkCli

    desc 'resultset SUBCOMMAND', 'Manage benchmark resultsets (collections of runs)'
    subcommand 'resultset', Serialbench::Cli::ResultsetCli

    desc 'ruby_build SUBCOMMAND', 'Manage Ruby-Build definitions for validation'
    subcommand 'ruby_build', Serialbench::Cli::RubyBuildCli

    desc 'version', 'Show Serialbench version'
    def self.version
      puts "Serialbench version #{Serialbench::VERSION}"
    end

    desc 'help [COMMAND]', 'Show help for commands'
    def help(command = nil)
      if command
        super(command)
      else
        puts <<~HELP
          Serialbench - Benchmarking Framework for Ruby Serialization Libraries

          USAGE:
            serialbench COMMAND [SUBCOMMAND] [OPTIONS]

          COMMANDS:
            environment   Manage benchmark environments (Docker, ASDF, Local)
            benchmark     Manage individual benchmark runs
            resultset     Manage benchmark resultsets (collections of runs)
            ruby-build    Manage Ruby-Build definitions for validation
            version       Show version information
            help          Show this help message

          EXAMPLES:
            # Create a Docker environment
            serialbench environment new docker-test docker

            # Run multi-environment benchmarks
            serialbench environment multi-execute asdf --config=serialbench-asdf.yml
            serialbench environment multi-execute docker --config=serialbench-docker.yml

            # Create and execute a benchmark
            serialbench benchmark create my-benchmark
            serialbench benchmark execute my-benchmark.yml

            # Create a result set for comparison
            serialbench resultset create comparison-set
            serialbench resultset add-result comparison-set results/my-benchmark

            # Generate static sites
            serialbench benchmark build-site results/my-benchmark
            serialbench resultset build-site resultsets/comparison-set

          For detailed help on any command, use:
            serialbench COMMAND help
        HELP
      end
    end

    # Handle unknown commands gracefully
    def method_missing(method_name, *_args)
      puts "Unknown command: #{method_name}"
      puts ''
      help
      exit 1
    end

    def respond_to_missing?(_method_name, _include_private = false)
      false
    end
  end
end
