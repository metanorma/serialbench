# frozen_string_literal: true

require 'benchmark'
require 'benchmark/ips'
require_relative 'serializers'

begin
  require 'memory_profiler'
rescue LoadError
  # Memory profiler is optional
end

module Serialbench
  class BenchmarkRunner
    attr_reader :serializers, :test_data, :results, :formats

    def initialize(formats: FORMATS, iterations: nil, warmup: nil, config: nil, **options)
      @formats = Array(formats)
      @config = config
      @options = options
      @options[:iterations] = iterations if iterations
      @options[:warmup] = warmup if warmup
      @serializers = load_available_serializers
      @test_data = {}
      @results = {}
      load_test_data
    end

    def run_all_benchmarks
      puts 'Serialbench - Running comprehensive serialization performance tests'
      puts '=' * 70
      puts "Available serializers: #{@serializers.map(&:name).join(', ')}"
      puts "Test formats: #{@formats.join(', ')}"
      puts "Test data sizes: #{@test_data.keys.join(', ')}"
      puts

      @results = {
        environment: collect_environment_info,
        parsing: run_parsing_benchmarks,
        generation: run_generation_benchmarks,
        memory_usage: run_memory_benchmarks
      }

      # Add streaming benchmarks if any serializers support it
      streaming_serializers = @serializers.select(&:supports_streaming?)
      @results[:streaming] = run_streaming_benchmarks if streaming_serializers.any?

      @results
    end

    def environment_info
      collect_environment_info
    end

    def run_parsing_benchmarks
      puts 'Running parsing benchmarks...'
      results = {}

      @test_data.each do |size, format_data|
        puts "  Testing #{size} files..."
        results[size] = {}

        format_data.each do |format, data|
          next unless @formats.include?(format)

          results[size][format] = {}
          iterations = get_iterations_for_size(size)

          serializers_for_format(format).each do |serializer|
            next unless serializer.available?

            begin
              # Warmup
              3.times { serializer.parse(data) }

              # Benchmark
              time = Benchmark.realtime do
                iterations.times { serializer.parse(data) }
              end

              results[size][format][serializer.name] = {
                time_per_iterations: time,
                time_per_iteration: time / iterations.to_f,
                iterations_per_second: iterations.to_f / time,
                iterations_count: iterations
              }

              puts "    #{format}/#{serializer.name}: #{(time / iterations.to_f * 1000).round(2)}ms per parse"
            rescue StandardError => e
              puts "    #{format}/#{serializer.name}: ERROR - #{e.message}"
              results[size][format][serializer.name] = { error: e.message }
            end
          end
        end
      end

      results
    end

    def run_generation_benchmarks
      puts "\nRunning generation benchmarks..."
      results = {}

      @test_data.each do |size, format_data|
        puts "  Testing #{size} files..."
        results[size] = {}

        format_data.each do |format, data|
          next unless @formats.include?(format)

          results[size][format] = {}
          iterations = get_iterations_for_size(size)

          serializers_for_format(format).each do |serializer|
            next unless serializer.available?

            begin
              # Parse document first to get object for generation
              document = serializer.parse(data)

              # Warmup
              3.times { serializer.generate(document) }

              # Benchmark
              time = Benchmark.realtime do
                iterations.times { serializer.generate(document) }
              end

              results[size][format][serializer.name] = {
                time_per_iterations: time,
                time_per_iteration: time / iterations.to_f,
                iterations_per_second: iterations.to_f / time,
                iterations_count: iterations
              }

              puts "    #{format}/#{serializer.name}: #{(time / iterations.to_f * 1000).round(2)}ms per generation"
            rescue StandardError => e
              puts "    #{format}/#{serializer.name}: ERROR - #{e.message}"
              results[size][format][serializer.name] = { error: e.message }
            end
          end
        end
      end

      results
    end

    def run_streaming_benchmarks
      puts "\nRunning streaming benchmarks..."
      results = {}

      @test_data.each do |size, format_data|
        puts "  Testing #{size} files..."
        results[size] = {}

        format_data.each do |format, data|
          next unless @formats.include?(format)

          results[size][format] = {}
          iterations = get_iterations_for_size(size)

          serializers_for_format(format).select(&:supports_streaming?).each do |serializer|
            next unless serializer.available?

            begin
              # Warmup
              3.times { serializer.stream_parse(data) { |event, data| } }

              # Benchmark
              time = Benchmark.realtime do
                iterations.times { serializer.stream_parse(data) { |event, data| } }
              end

              results[size][format][serializer.name] = {
                time_per_iterations: time,
                time_per_iteration: time / iterations.to_f,
                iterations_per_second: iterations.to_f / time,
                iterations_count: iterations
              }

              puts "    #{format}/#{serializer.name}: #{(time / iterations.to_f * 1000).round(2)}ms per stream parse"
            rescue StandardError => e
              puts "    #{format}/#{serializer.name}: ERROR - #{e.message}"
              results[size][format][serializer.name] = { error: e.message }
            end
          end
        end
      end

      results
    end

    def run_memory_benchmarks
      puts "\nRunning memory usage benchmarks..."
      results = {}

      return results unless defined?(::MemoryProfiler)

      @test_data.each do |size, format_data|
        puts "  Testing #{size} files..."
        results[size] = {}

        format_data.each do |format, data|
          next unless @formats.include?(format)

          results[size][format] = {}

          serializers_for_format(format).each do |serializer|
            next unless serializer.available?

            begin
              # Memory profiling for parsing
              report = ::MemoryProfiler.report do
                10.times { serializer.parse(data) }
              end

              results[size][format][serializer.name] = {
                total_allocated: report.total_allocated,
                total_retained: report.total_retained,
                allocated_memory: report.total_allocated_memsize,
                retained_memory: report.total_retained_memsize
              }

              puts "    #{format}/#{serializer.name}: #{(report.total_allocated_memsize / 1024.0 / 1024.0).round(2)}MB allocated"
            rescue StandardError => e
              puts "    #{format}/#{serializer.name}: ERROR - #{e.message}"
              results[size][format][serializer.name] = { error: e.message }
            end
          end
        end
      end

      results
    end

    def serializers_for_format(format)
      @serializers.select { |s| s.format == format.to_sym }
    end

    def all_serializers
      @serializers
    end

    private

    def get_iterations_for_size(size)
      if @config && @config['iterations']
        @config['iterations'][size.to_s] || @config['iterations']['small'] || 5
      else
        case size
        when :small
          20
        when :medium
          5
        when :large
          2
        else
          10
        end
      end
    end

    def load_available_serializers
      Serializers.available.map(&:new)
    end

    def load_test_data
      # Determine which data sizes to load based on configuration
      data_sizes = if @config && @config['data_sizes']
                     @config['data_sizes'].map(&:to_sym)
                   else
                     [:small, :medium, :large]
                   end

      # Initialize test data structure
      @test_data = {}
      data_sizes.each { |size| @test_data[size] = {} }

      # Generate data for each format and size
      @formats.each do |format|
        data_sizes.each do |size|
          case format
          when :xml
            @test_data[size][:xml] = case size
                                     when :small
                                       generate_small_xml
                                     when :medium
                                       generate_medium_xml
                                     when :large
                                       generate_large_xml
                                     end
          when :json
            @test_data[size][:json] = case size
                                      when :small
                                        generate_small_json
                                      when :medium
                                        generate_medium_json
                                      when :large
                                        generate_large_json
                                      end
          when :yaml
            @test_data[size][:yaml] = case size
                                      when :small
                                        generate_small_yaml
                                      when :medium
                                        generate_medium_yaml
                                      when :large
                                        generate_large_yaml
                                      end
          when :toml
            @test_data[size][:toml] = case size
                                      when :small
                                        generate_small_toml
                                      when :medium
                                        generate_medium_toml
                                      when :large
                                        generate_large_toml
                                      end
          end
        end
      end

      # Try to load real test files if they exist
      data_sizes.each do |size|
        @formats.each do |format|
          file_path = "test_data/#{size}.#{format}"
          @test_data[size][format] = File.read(file_path) if File.exist?(file_path)
        end
      end
    end

    # XML test data generators
    def generate_small_xml
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <config>
          <database>
            <host>localhost</host>
            <port>5432</port>
            <name>myapp</name>
            <user>admin</user>
            <password>secret</password>
          </database>
          <cache>
            <enabled>true</enabled>
            <ttl>3600</ttl>
          </cache>
        </config>
      XML
    end

    def generate_medium_xml
      users = (1..1000).map do |i|
        <<~USER
          <user id="#{i}">
            <name>User #{i}</name>
            <email>user#{i}@example.com</email>
            <created_at>2023-01-#{(i % 28) + 1}T10:00:00Z</created_at>
            <profile>
              <age>#{20 + (i % 50)}</age>
              <city>City #{i % 100}</city>
              <preferences>
                <theme>#{i.even? ? 'dark' : 'light'}</theme>
                <notifications>#{i % 3 == 0 ? 'true' : 'false'}</notifications>
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
      records = (1..10_000).map do |i|
        <<~RECORD
          <record id="#{i}">
            <timestamp>2023-01-01T#{format('%02d', i % 24)}:#{format('%02d', i % 60)}:#{format('%02d', i % 60)}Z</timestamp>
            <data>
              <field1>Value #{i}</field1>
              <field2>#{i * 2}</field2>
              <field3>#{i % 100 == 0 ? 'special' : 'normal'}</field3>
              <nested>
                <item>Item #{i}-1</item>
                <item>Item #{i}-2</item>
                <item>Item #{i}-3</item>
              </nested>
            </data>
            <metadata>
              <source>generator</source>
              <version>1.0</version>
              <checksum>#{i.to_s(16)}</checksum>
            </metadata>
          </record>
        RECORD
      end.join

      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <dataset>
          <header>
            <created>2023-01-01T00:00:00Z</created>
            <count>10000</count>
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
      require 'json'
      JSON.generate({
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
                    })
    end

    def generate_medium_json
      require 'json'
      users = (1..1000).map do |i|
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
              notifications: i % 3 == 0
            }
          }
        }
      end

      JSON.generate({ users: users })
    end

    def generate_large_json
      require 'json'
      records = (1..10_000).map do |i|
        {
          id: i,
          timestamp: "2023-01-01T#{format('%02d', i % 24)}:#{format('%02d', i % 60)}:#{format('%02d', i % 60)}Z",
          data: {
            field1: "Value #{i}",
            field2: i * 2,
            field3: i % 100 == 0 ? 'special' : 'normal',
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

      JSON.generate({
                      dataset: {
                        header: {
                          created: '2023-01-01T00:00:00Z',
                          count: 10_000,
                          format: 'json'
                        },
                        records: records
                      }
                    })
    end

    # YAML test data generators
    def generate_small_yaml
      require 'yaml'
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
      }.to_yaml
    end

    def generate_medium_yaml
      require 'yaml'
      users = (1..1000).map do |i|
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
              notifications: i % 3 == 0
            }
          }
        }
      end

      { users: users }.to_yaml
    end

    def generate_large_yaml
      require 'yaml'
      records = (1..10_000).map do |i|
        {
          id: i,
          timestamp: "2023-01-01T#{format('%02d', i % 24)}:#{format('%02d', i % 60)}:#{format('%02d', i % 60)}Z",
          data: {
            field1: "Value #{i}",
            field2: i * 2,
            field3: i % 100 == 0 ? 'special' : 'normal',
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

      {
        dataset: {
          header: {
            created: '2023-01-01T00:00:00Z',
            count: 10_000,
            format: 'yaml'
          },
          records: records
        }
      }.to_yaml
    end

    # TOML test data generators
    def generate_small_toml
      <<~TOML
        [config]

        [config.database]
        host = "localhost"
        port = 5432
        name = "myapp"
        user = "admin"
        password = "secret"

        [config.cache]
        enabled = true
        ttl = 3600
      TOML
    end

    def generate_medium_toml
      (1..100).map do |i| # Smaller for TOML due to verbosity
        <<~USER
          [[users]]
          id = #{i}
          name = "User #{i}"
          email = "user#{i}@example.com"
          created_at = "2023-01-#{(i % 28) + 1}T10:00:00Z"

          [users.profile]
          age = #{20 + (i % 50)}
          city = "City #{i % 100}"

          [users.profile.preferences]
          theme = "#{i.even? ? 'dark' : 'light'}"
          notifications = #{i % 3 == 0}
        USER
      end.join("\n")
    end

    def generate_large_toml
      records_toml = (1..1000).map do |i| # Smaller for TOML due to verbosity
        <<~RECORD
          [[dataset.records]]
          id = #{i}
          timestamp = "2023-01-01T#{format('%02d', i % 24)}:#{format('%02d', i % 60)}:#{format('%02d', i % 60)}Z"

          [dataset.records.data]
          field1 = "Value #{i}"
          field2 = #{i * 2}
          field3 = "#{i % 100 == 0 ? 'special' : 'normal'}"
          nested = ["Item #{i}-1", "Item #{i}-2", "Item #{i}-3"]

          [dataset.records.metadata]
          source = "generator"
          version = "1.0"
          checksum = "#{i.to_s(16)}"
        RECORD
      end.join("\n")

      <<~TOML
        [dataset]

        [dataset.header]
        created = "2023-01-01T00:00:00Z"
        count = 1000
        format = "toml"

        #{records_toml}
      TOML
    end

    def collect_environment_info
      {
        ruby_version: RUBY_VERSION,
        ruby_platform: RUBY_PLATFORM,
        serializer_versions: @serializers.map { |s| [s.name, s.version] }.to_h,
        timestamp: Time.now.iso8601
      }
    end
  end
end
