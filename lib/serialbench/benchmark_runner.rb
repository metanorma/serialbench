# frozen_string_literal: true

require 'benchmark'
require 'benchmark/ips'
require_relative 'serializers'
require_relative 'models/benchmark_result'

begin
  require 'memory_profiler'
rescue LoadError
  # Memory profiler is optional
end

module Serialbench
  class BenchmarkRunner
    attr_reader :environment_config, :benchmark_config, :serializers, :test_data, :results

    def initialize(benchmark_config:, environment_config:)
      @environment_config = environment_config
      @benchmark_config = benchmark_config
      @serializers = Serializers.available
      @test_data = {}
      @results = []
      load_test_data
    end

    def run_all_benchmarks
      puts 'Serialbench - Running comprehensive serialization performance tests'
      puts '=' * 70
      puts "Available serializers: #{@serializers.map(&:name).join(', ')}"
      puts "Test formats: #{@benchmark_config.formats.join(', ')}"
      puts "Test data sizes: #{@test_data.keys.join(', ')}"
      puts

      Models::BenchmarkResult.new(
        serializers: Serializers.information,
        parsing: run_parsing_benchmarks,
        generation: run_generation_benchmarks,
        memory_usage: run_memory_benchmarks,
        streaming: run_streaming_benchmarks
      )
    end

    def run_parsing_benchmarks
      run_benchmark_type('parsing', 'parse') do |serializer, data|
        serializer.parse(data)
      end
    end

    def run_generation_benchmarks
      run_benchmark_type('generation', 'generation') do |serializer, data|
        document = serializer.parse(data)
        serializer.generate(document)
      end
    end

    def run_streaming_benchmarks
      run_benchmark_type('streaming', 'stream parse') do |serializer, data|
        serializer.stream_parse(data) { |event, data| }
      end
    end

    def run_memory_benchmarks
      puts "\nRunning memory usage benchmarks..."
      return [] unless defined?(::MemoryProfiler)

      run_benchmark_iteration('memory') do |serializer, format, size, data|
        # Memory profiling for parsing
        report = ::MemoryProfiler.report do
          10.times { serializer.parse(data) }
        end

        result = Models::MemoryPerformance.new(
          adapter: serializer.name,
          format: format,
          data_size: size,
          total_allocated: report.total_allocated,
          total_retained: report.total_retained,
          allocated_memory: report.total_allocated_memsize,
          retained_memory: report.total_retained_memsize
        )

        puts "    #{format}/#{serializer.name}: #{(report.total_allocated_memsize / 1024.0 / 1024.0).round(2)}MB allocated"
        result
      end
    end

    private

    def run_benchmark_type(type_name, operation_name, &block)
      puts "#{type_name == 'parsing' ? '' : "\n"}Running #{type_name} benchmarks..."

      run_benchmark_iteration(type_name) do |serializer, format, size, data|
        iterations = get_iterations_for_size(size)

        # Warmup
        3.times { block.call(serializer, data) }

        # Benchmark
        time = Benchmark.realtime do
          iterations.times { block.call(serializer, data) }
        end

        result = Models::IterationPerformance.new(
          adapter: serializer.name,
          format: format,
          data_size: size,
          time_per_iterations: time,
          time_per_iteration: time / iterations.to_f,
          iterations_per_second: iterations.to_f / time,
          iterations_count: iterations
        )

        puts "    #{result.format}/#{result.adapter}: #{(result.time_per_iteration * 1000).round(2)}ms per #{operation_name}"
        result
      end
    end

    def run_benchmark_iteration(type_name)
      results = []

      @test_data.each do |size, format_data|
        puts "  Testing #{size} files..."

        format_data.each do |format, data|
          next unless @benchmark_config.formats.include?(format)

          serializers = get_serializers_for_benchmark_type(type_name, format)

          serializers.each do |serializer|
            next unless serializer.available?

            begin
              result = yield(serializer, format, size, data)
              results << result if result
            rescue StandardError => e
              puts "    #{format}/#{serializer.name}: ERROR - #{e.message}"
            end
          end
        end
      end

      results
    end

    def get_serializers_for_benchmark_type(type_name, format)
      serializers = Serializers.for_format(format)

      case type_name
      when 'generation'
        serializers.select(&:supports_generation?)
      when 'streaming'
        serializers.select(&:supports_streaming?)
      else
        serializers
      end
    end

    def get_iterations_for_size(size)
      @benchmark_config.iterations.send(size.to_s)
    end

    def load_test_data
      # Determine which data sizes to load based on configuration
      data_sizes = @benchmark_config.data_sizes

      # Initialize test data structure
      @test_data = {}
      data_sizes.each { |size| @test_data[size] = {} }

      # Generate data for each format and size
      @benchmark_config.formats.each do |format|
        data_sizes.each do |size|
          @test_data[size][format] = generate_test_data(format, size)
        end
      end

      # Try to load real test files if they exist
      data_sizes.each do |size|
        @benchmark_config.formats.each do |format|
          file_path = "test_data/#{size}.#{format}"
          @test_data[size][format] = File.read(file_path) if File.exist?(file_path)
        end
      end
    end

    def generate_test_data(format, size)
      method_name = "generate_#{size}_#{format}"
      send(method_name)
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
