# frozen_string_literal: true

require 'rspec'
require_relative '../lib/serialbench'

# Ensure we use Psych for YAML parsing
require 'psych'
Object.const_set(:YAML, Psych)

# Helper method to create test XML
def create_test_xml(size)
  case size
  when :small
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <root>
        <item id="1">
          <name>Test Item</name>
          <value>100</value>
        </item>
      </root>
    XML
  when :medium
    items = (1..10).map do |i|
      "  <item id=\"#{i}\">\n    <name>Item #{i}</name>\n    <value>#{i * 100}</value>\n  </item>"
    end.join("\n")
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <root>
      #{items}
      </root>
    XML
  when :large
    items = (1..100).map do |i|
      "  <item id=\"#{i}\">\n    <name>Item #{i}</name>\n    <value>#{i * 100}</value>\n  </item>"
    end.join("\n")
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <root>
      #{items}
      </root>
    XML
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

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

  # Make helper methods available
  config.include Module.new {
    def create_test_xml(size)
      case size
      when :small
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <root>
            <item id="1">
              <name>Test Item</name>
              <value>100</value>
            </item>
          </root>
        XML
      when :medium
        items = (1..10).map do |i|
          "  <item id=\"#{i}\">\n    <name>Item #{i}</name>\n    <value>#{i * 100}</value>\n  </item>"
        end.join("\n")
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <root>
          #{items}
          </root>
        XML
      when :large
        items = (1..100).map do |i|
          "  <item id=\"#{i}\">\n    <name>Item #{i}</name>\n    <value>#{i * 100}</value>\n  </item>"
        end.join("\n")
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <root>
          #{items}
          </root>
        XML
      end
    end
  }
end
