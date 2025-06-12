# frozen_string_literal: true

require_relative 'serialbench/version'
require_relative 'serialbench/serializers'
require_relative 'serialbench/benchmark_runner'
require_relative 'serialbench/cli'
require_relative 'serialbench/memory_profiler'
require_relative 'serialbench/models'
require_relative 'serialbench/site_generator'

module Serialbench
  class Error < StandardError; end
end
