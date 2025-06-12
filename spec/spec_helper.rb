# frozen_string_literal: true

require 'rspec'
require_relative '../lib/serialbench'

# Ensure we use Psych for YAML parsing
require 'psych'
Object.const_set(:YAML, Psych)

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_path = '.rspec_status'

  # Disable RSpec exposing methods globally on Module and main
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Filter out third-party code from backtraces
  config.filter_gems_from_backtrace 'nokogiri', 'ox', 'libxml-ruby', 'oga'

  # Configure output format
  config.formatter = :documentation
  config.color = true
end
