# frozen_string_literal: true

module Serialbench
  # Fixture documents for every format x size the benchmark engine measures.
  class TestData
    def self.load(config)
      new(config).load
    end

    def initialize(config)
      @config = config
    end

    def load
      @config.data_sizes.each_with_object({}) do |size, data|
        data[size] = @config.formats.each_with_object({}) do |format, formats|
          formats[format] = fixture_file(size, format) || generate("#{size}.#{format}")
        end
      end
    end

    private

    def fixture_file(size, format)
      path = "test_data/#{size}.#{format}"
      File.read(path) if File.exist?(path)
    end

    def generate(key)
      case key
      when 'small.xml' then generate_small_xml
      when 'medium.xml' then generate_medium_xml
      when 'large.xml' then generate_large_xml
      when 'small.json' then generate_small_json
      when 'medium.json' then generate_medium_json
      when 'large.json' then generate_large_json
      when 'small.yaml' then generate_small_yaml
      when 'medium.yaml' then generate_medium_yaml
      when 'large.yaml' then generate_large_yaml
      when 'small.toml' then generate_small_toml
      when 'medium.toml' then generate_medium_toml
      when 'large.toml' then generate_large_toml
      else raise ArgumentError, "no test data generator for #{key}"
      end
    end

    # Shared data structure generators
    def small_test_data_structure
      {
        config: {
          database: {
            host: 'localhost',
            port: 5432,
            name: 'myapp',
            user: 'admin',
            password: 'secret'
          },
          cache: {
            enabled: true,
            ttl: 3600
          }
        }
      }
    end

    def medium_test_data_structure
      {
        users: (1..1000).map do |i|
          {
            id: i,
            name: "User #{i}",
            email: "user#{i}@example.com",
            created_at: "2023-01-#{(i % 28) + 1}T10:00:00Z",
            profile: {
              age: 20 + (i % 50),
              city: "City #{i % 100}",
              preferences: {
                theme: i.even? ? 'dark' : 'light',
                notifications: (i % 3).zero?
              }
            }
          }
        end
      }
    end

    def large_test_data_structure
      {
        dataset: {
          header: {
            created: '2023-01-01T00:00:00Z',
            count: 10_000,
            format: 'data'
          },
          records: (1..10_000).map do |i|
            {
              id: i,
              timestamp: "2023-01-01T#{format('%02d', i % 24)}:#{format('%02d', i % 60)}:#{format('%02d', i % 60)}Z",
              data: {
                field1: "Value #{i}",
                field2: i * 2,
                field3: (i % 100).zero? ? 'special' : 'normal',
                nested: [
                  "Item #{i}-1",
                  "Item #{i}-2",
                  "Item #{i}-3"
                ]
              },
              metadata: {
                source: 'generator',
                version: '1.0',
                checksum: i.to_s(16)
              }
            }
          end
        }
      }
    end

    # XML test data generators
    def generate_small_xml
      data = small_test_data_structure
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <config>
          <database>
            <host>#{data[:config][:database][:host]}</host>
            <port>#{data[:config][:database][:port]}</port>
            <name>#{data[:config][:database][:name]}</name>
            <user>#{data[:config][:database][:user]}</user>
            <password>#{data[:config][:database][:password]}</password>
          </database>
          <cache>
            <enabled>#{data[:config][:cache][:enabled]}</enabled>
            <ttl>#{data[:config][:cache][:ttl]}</ttl>
          </cache>
        </config>
      XML
    end

    def generate_medium_xml
      data = medium_test_data_structure
      users = data[:users].map do |user|
        <<~USER
          <user id="#{user[:id]}">
            <name>#{user[:name]}</name>
            <email>#{user[:email]}</email>
            <created_at>#{user[:created_at]}</created_at>
            <profile>
              <age>#{user[:profile][:age]}</age>
              <city>#{user[:profile][:city]}</city>
              <preferences>
                <theme>#{user[:profile][:preferences][:theme]}</theme>
                <notifications>#{user[:profile][:preferences][:notifications]}</notifications>
              </preferences>
            </profile>
          </user>
        USER
      end.join

      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <users>
          #{users}
        </users>
      XML
    end

    def generate_large_xml
      data = large_test_data_structure
      records = data[:dataset][:records].map do |record|
        nested_items = record[:data][:nested].map { |item| "    <item>#{item}</item>" }.join("\n")
        <<~RECORD
            <record id="#{record[:id]}">
              <timestamp>#{record[:timestamp]}</timestamp>
              <data>
                <field1>#{record[:data][:field1]}</field1>
                <field2>#{record[:data][:field2]}</field2>
                <field3>#{record[:data][:field3]}</field3>
                <nested>
          #{nested_items}
                </nested>
              </data>
              <metadata>
                <source>#{record[:metadata][:source]}</source>
                <version>#{record[:metadata][:version]}</version>
                <checksum>#{record[:metadata][:checksum]}</checksum>
              </metadata>
            </record>
        RECORD
      end.join

      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <dataset>
          <header>
            <created>#{data[:dataset][:header][:created]}</created>
            <count>#{data[:dataset][:header][:count]}</count>
            <format>xml</format>
          </header>
          <records>
            #{records}
          </records>
        </dataset>
      XML
    end

    # JSON test data generators
    def generate_small_json
      JSON.generate(small_test_data_structure)
    end

    def generate_medium_json
      JSON.generate(medium_test_data_structure)
    end

    def generate_large_json
      data = large_test_data_structure
      data[:dataset][:header][:format] = 'json'
      JSON.generate(data)
    end

    # YAML test data generators
    def generate_small_yaml
      small_test_data_structure.to_yaml
    end

    def generate_medium_yaml
      medium_test_data_structure.to_yaml
    end

    def generate_large_yaml
      data = large_test_data_structure
      data[:dataset][:header][:format] = 'yaml'
      data.to_yaml
    end

    # TOML test data generators
    def generate_small_toml
      data = small_test_data_structure
      <<~TOML
        [config]

        [config.database]
        host = "#{data[:config][:database][:host]}"
        port = #{data[:config][:database][:port]}
        name = "#{data[:config][:database][:name]}"
        user = "#{data[:config][:database][:user]}"
        password = "#{data[:config][:database][:password]}"

        [config.cache]
        enabled = #{data[:config][:cache][:enabled]}
        ttl = #{data[:config][:cache][:ttl]}
      TOML
    end

    def generate_medium_toml
      data = medium_test_data_structure
      # Use smaller dataset for TOML due to verbosity
      users = data[:users].first(100)
      users.map do |user|
        <<~USER
          [[users]]
          id = #{user[:id]}
          name = "#{user[:name]}"
          email = "#{user[:email]}"
          created_at = "#{user[:created_at]}"

          [users.profile]
          age = #{user[:profile][:age]}
          city = "#{user[:profile][:city]}"

          [users.profile.preferences]
          theme = "#{user[:profile][:preferences][:theme]}"
          notifications = #{user[:profile][:preferences][:notifications]}
        USER
      end.join("\n")
    end

    def generate_large_toml
      data = large_test_data_structure
      # Use smaller dataset for TOML due to verbosity
      records = data[:dataset][:records].first(1000)
      records_toml = records.map do |record|
        <<~RECORD
          [[dataset.records]]
          id = #{record[:id]}
          timestamp = "#{record[:timestamp]}"

          [dataset.records.data]
          field1 = "#{record[:data][:field1]}"
          field2 = #{record[:data][:field2]}
          field3 = "#{record[:data][:field3]}"
          nested = #{record[:data][:nested].inspect}

          [dataset.records.metadata]
          source = "#{record[:metadata][:source]}"
          version = "#{record[:metadata][:version]}"
          checksum = "#{record[:metadata][:checksum]}"
        RECORD
      end.join("\n")

      <<~TOML
        [dataset]

        [dataset.header]
        created = "#{data[:dataset][:header][:created]}"
        count = #{records.length}
        format = "toml"

        #{records_toml}
      TOML
    end
  end
end
