# frozen_string_literal: true

require 'thor'
require_relative 'cli/base_cli'
require_relative 'cli/environment_cli'
require_relative 'cli/run_cli'
require_relative 'cli/runset_cli'

module Serialbench
  # Main CLI entry point for the new object-oriented command structure
  class CLI < Serialbench::Cli::BaseCli
    desc 'environment SUBCOMMAND', 'Manage benchmark environments'
    subcommand 'environment', Serialbench::Cli::EnvironmentCli

    desc 'benchmark SUBCOMMAND', 'Manage individual benchmark runs'
    subcommand 'benchmark', Serialbench::Cli::RunCli

    desc 'runset SUBCOMMAND', 'Manage benchmark runsets (collections of runs)'
    subcommand 'runset', Serialbench::Cli::RunsetCli

    desc 'version', 'Show Serialbench version'
    def version
      puts "Serialbench version #{Serialbench::VERSION}"
    end

    desc 'help [COMMAND]', 'Show help for commands'
    def help(command = nil)
      if command
        super(command)
      else
        puts <<~HELP
          Serialbench - Object-Oriented Serialization Benchmarking Framework

          USAGE:
            serialbench COMMAND [SUBCOMMAND] [OPTIONS]

          COMMANDS:
            environment    Manage benchmark environments (Docker, ASDF, Local)
            benchmark     Manage individual benchmark runs
            runset        Manage benchmark runsets (collections of runs)
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
            serialbench runset create comparison-set
            serialbench runset add-run comparison-set results/my-benchmark

            # Generate static sites
            serialbench benchmark build-site results/my-benchmark
            serialbench runset build-site resultsets/comparison-set

          For detailed help on any command, use:
            serialbench COMMAND help
        HELP
      end
    end

    # Handle unknown commands gracefully
    def method_missing(method_name, *args)
      puts "Unknown command: #{method_name}"
      puts ''
      help
      exit 1
    end

    def respond_to_missing?(method_name, include_private = false)
      false
    end
  end
end
