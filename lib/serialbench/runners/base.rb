# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'yaml'
require 'open3'
require 'stringio'

module Serialbench
  module Runners
    # Runner protocol: prepare, then run_benchmark(config, config_path, result_dir)
    class Base
      def initialize(environment_config, environment_config_path)
        @environment_config = environment_config
        @environment_config_path = environment_config_path

        raise 'environment_config is required' unless @environment_config
        raise 'environment_config_path is required' unless @environment_config_path
        raise 'environment_config_path must be a valid file' unless File.exist?(@environment_config_path)
      end

      def prepare
        raise NotImplementedError, 'Subclasses must implement the prepare method'
      end

      def run_benchmark(benchmark_config, benchmark_config_path, result_dir)
        raise NotImplementedError, 'Subclasses must implement the run_benchmark method'
      end
    end
  end
end
