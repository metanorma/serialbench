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
      validate_operations!
      load_test_data
    end

    # Each operation maps to a lambda. Adding an operation = one entry.
    OPERATIONS = {
      'parsing' => ->(s, data) { s.parse(data) },
      'generation' => ->(s, data) { s.generate(s.parse(data)) },
      'xpath' => lambda { |s, data|
        doc = s.parse(data)
        s.xpath_query(doc, '//book')
        s.xpath_query(doc, "//book[@id='101']")
        s.xpath_query(doc, '//book[price > 30]/title')
      },
      'streaming' => ->(s, data) { s.stream_parse(data) { |_event, _data| } },
    }.freeze

    def run_all_benchmarks
      puts 'Serialbench - Running comprehensive serialization performance tests'
      puts '=' * 70
      puts "Available serializers: #{@serializers.map(&:name).join(', ')}"
      puts "Test formats: #{@benchmark_config.formats.join(', ')}"
      puts "Test data sizes: #{@test_data.keys.join(', ')}"
      puts

      selected = @benchmark_config.operations
      selected = OPERATIONS.keys + ['memory'] if selected.nil? || selected.empty?
      results = {}
      OPERATIONS.each do |name, handler|
        results[name.to_sym] = selected.include?(name) ? run_benchmark_type(name, name, &handler) : []
      end
      results[:memory] = selected.include?('memory') ? run_memory_benchmarks : []

      Models::BenchmarkResult.new(
        serializers: Serializers.information,
        **results
      )
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
            ensure
              # Free the previous adapter's documents before the next one
              # parses + profiles; without this, six adapters' trees coexist
              # and windows runners OOM during the xml memory pass.
              GC.start
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
        serializers.select { |s| s.supports?(:generate) }
      when 'streaming'
        serializers.select { |s| s.supports?(:sax) || s.supports?(:streaming) }
      when 'xpath'
        serializers.select { |s| s.supports?(:xpath) }
      else
        serializers
      end
    end

    def get_iterations_for_size(size)
      iterations = @benchmark_config.iterations
      case size.to_s
      when 'small' then iterations.small
      when 'medium' then iterations.medium
      when 'large' then iterations.large
      else raise ArgumentError, "no iteration count configured for #{size}"
      end
    end

    def validate_operations!
      unknown = (@benchmark_config.operations || []) - (OPERATIONS.keys + ['memory'])
      return if unknown.empty?

      raise ArgumentError, "unknown operations #{unknown.inspect}; expected: #{OPERATIONS.keys.join(', ')}, memory"
    end

    def load_test_data
      @test_data = TestData.load(@benchmark_config)
    end
  end
end
