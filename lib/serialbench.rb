# frozen_string_literal: true

require_relative 'serialbench/version'
require_relative 'serialbench/serializers'
require_relative 'serialbench/benchmark_runner'
require_relative 'serialbench/result_merger'
require_relative 'serialbench/cli'
require_relative 'serialbench/result_formatter'
require_relative 'serialbench/chart_generator'
require_relative 'serialbench/memory_profiler'

module Serialbench
  class Error < StandardError; end

  # Supported serialization formats
  FORMATS = %i[xml json toml].freeze

  def self.run_benchmarks(formats: FORMATS, options: {})
    runner = BenchmarkRunner.new(formats: formats, **options)
    runner.run_all_benchmarks
  end

  def self.available_serializers(format = nil)
    runner = BenchmarkRunner.new
    if format
      runner.serializers_for_format(format)
    else
      runner.all_serializers
    end
  end

  def self.generate_reports(results)
    result_merger = Serialbench::ResultMerger.new
    result_merger.generate_all_reports(results)
  end

  def self.generate_reports_from_data(data_file)
    require 'json'
    data = JSON.parse(File.read(data_file), symbolize_names: true)
    generate_reports(data)
  end
end
