# frozen_string_literal: true

require 'rspec'
require_relative '../lib/serialbench'

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

  # Shared test data directory
  config.before(:suite) do
    @test_data_dir = File.join(__dir__, 'fixtures')
    FileUtils.mkdir_p(@test_data_dir) unless Dir.exist?(@test_data_dir)
  end

  # Clean up after tests
  config.after(:suite) do
    test_output_dir = File.join(__dir__, '..', 'tmp', 'test_output')
    FileUtils.rm_rf(test_output_dir) if Dir.exist?(test_output_dir)
  end
end

# Helper method to create test XML data
def create_test_xml(size = :small)
  case size
  when :small
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <config>
        <database>
          <host>localhost</host>
          <port>5432</port>
          <name>test_db</name>
        </database>
        <cache enabled="true">
          <ttl>3600</ttl>
        </cache>
      </config>
    XML
  when :medium
    users = (1..100).map do |i|
      <<~XML
        <user id="#{i}">
          <name>User #{i}</name>
          <email>user#{i}@example.com</email>
          <created_at>#{Time.now.iso8601}</created_at>
          <profile>
            <age>#{20 + (i % 50)}</age>
            <city>City #{i % 10}</city>
            <preferences>
              <theme>#{%w[light dark].sample}</theme>
              <notifications>#{[true, false].sample}</notifications>
            </preferences>
          </profile>
        </user>
      XML
    end.join("\n")

    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <users>
        #{users}
      </users>
    XML
  when :large
    records = (1..1000).map do |i|
      <<~XML
        <record id="#{i}">
          <timestamp>#{Time.now.iso8601}</timestamp>
          <data>
            <field1>Value #{i}</field1>
            <field2>#{rand(1000)}</field2>
            <field3>#{%w[A B C D E].sample}</field3>
            <nested>
              <item>Item #{i}-1</item>
              <item>Item #{i}-2</item>
              <item>Item #{i}-3</item>
            </nested>
          </data>
        </record>
      XML
    end.join("\n")

    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <dataset>
        <metadata>
          <version>1.0</version>
          <generated>#{Time.now.iso8601}</generated>
          <count>1000</count>
        </metadata>
        <records>
          #{records}
        </records>
      </dataset>
    XML
  end
end

# Helper method to create temporary files
def create_temp_xml_file(content, filename = nil)
  filename ||= "test_#{SecureRandom.hex(8)}.xml"
  filepath = File.join(Dir.tmpdir, filename)
  File.write(filepath, content)
  filepath
end

# Helper method to clean up temporary files
def cleanup_temp_file(filepath)
  File.delete(filepath) if File.exist?(filepath)
end
