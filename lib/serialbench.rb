# frozen_string_literal: true

require_relative 'serialbench/version'
require_relative 'serialbench/serializers'
require_relative 'serialbench/benchmark_runner'
require_relative 'serialbench/cli'
require_relative 'serialbench/models'

module Serialbench
  autoload :TestData, 'serialbench/test_data'
  autoload :Runners, 'serialbench/runners'

  class Error < StandardError; end
end
