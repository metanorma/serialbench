# frozen_string_literal: true

require 'yaml'
require 'time'
require 'fileutils'

module Serialbench
  module Models
    # Benchmark result model
    class Result
      attr_reader :name, :environment, :benchmark_config, :execution, :results, :metadata

      def initialize(config_hash)
        @config = config_hash.dup
        @name = config_hash['name']
        @environment = config_hash['environment']
        @benchmark_config = config_hash['benchmark_config']
        @execution = config_hash['execution']
        @results = config_hash['results']
        @metadata = config_hash['metadata']

        validate!
      end

      def self.load_from_file(file_path)
        config = YAML.load_file(file_path)
        new(config)
      rescue StandardError => e
        raise "Failed to load result from #{file_path}: #{e.message}"
      end

      def self.load_from_directory(result_dir)
        result_file = File.join(result_dir, 'result.yml')
        raise "Result file not found: #{result_file}" unless File.exist?(result_file)

        load_from_file(result_file)
      end

      def self.create(name, environment, benchmark_config)
        config = {
          'name' => name,
          'environment' => environment_info(environment),
          'benchmark_config' => benchmark_config_info(benchmark_config),
          'execution' => {
            'started_at' => Time.now.iso8601,
            'status' => 'running'
          },
          'results' => {
            'parsing' => {},
            'generation' => {}
          },
          'metadata' => {
            'serializer_versions' => {},
            'system_info' => system_info
          }
        }

        new(config)
      end

      def save_to_directory(result_dir)
        FileUtils.mkdir_p(result_dir)
        result_file = File.join(result_dir, 'result.yml')
        File.write(result_file, @config.to_yaml)
        result_file
      end

      def save_to_file(file_path)
        File.write(file_path, @config.to_yaml)
      end

      def started_at
        Time.parse(@execution['started_at']) if @execution['started_at']
      end

      def completed_at
        Time.parse(@execution['completed_at']) if @execution['completed_at']
      end

      def duration_seconds
        @execution['duration_seconds']
      end

      def status
        @execution['status']
      end

      def success?
        status == 'success'
      end

      def failed?
        status == 'failed'
      end

      def partial?
        status == 'partial'
      end

      def running?
        status == 'running'
      end

      def error_message
        @execution['error_message']
      end

      def warnings
        @execution['warnings'] || []
      end

      def environment_name
        @environment['name']
      end

      def environment_type
        @environment['type']
      end

      def ruby_version
        @environment['ruby_version']
      end

      def platform
        @environment['platform']
      end

      def formats
        @benchmark_config['formats'] || []
      end

      def data_sizes
        @benchmark_config['data_sizes'] || []
      end

      def iterations
        @benchmark_config['iterations']
      end

      def memory_profiling?
        @benchmark_config['memory_profiling'] == true
      end

      def serializer_versions
        @metadata['serializer_versions'] || {}
      end

      def system_info
        @metadata['system_info'] || {}
      end

      def notes
        @metadata['notes']
      end

      def notes=(value)
        @metadata['notes'] = value
      end

      # Result data access methods
      def parsing_results
        @results['parsing'] || {}
      end

      def generation_results
        @results['generation'] || {}
      end

      def streaming_results
        @results['streaming'] || {}
      end

      def memory_results
        @results['memory'] || {}
      end

      def get_result(operation, data_size, format, serializer)
        @results.dig(operation, data_size, format, serializer)
      end

      def set_result(operation, data_size, format, serializer, result_data)
        @results[operation] ||= {}
        @results[operation][data_size] ||= {}
        @results[operation][data_size][format] ||= {}
        @results[operation][data_size][format][serializer] = result_data
      end

      def add_serializer_version(name, version)
        @metadata['serializer_versions'][name] = version
      end

      def add_warning(message)
        @execution['warnings'] ||= []
        @execution['warnings'] << message
      end

      def mark_completed(status = 'success', error_message = nil)
        @execution['completed_at'] = Time.now.iso8601
        @execution['status'] = status
        @execution['error_message'] = error_message if error_message

        return unless started_at && completed_at

        @execution['duration_seconds'] = (completed_at - started_at).round(2)
      end

      def to_h
        @config.dup
      end

      def to_yaml
        @config.to_yaml
      end

      def ==(other)
        other.is_a?(Result) && @config == other.instance_variable_get(:@config)
      end

      def hash
        @config.hash
      end

      # Summary methods for reporting
      def summary
        {
          name: @name,
          environment: environment_name,
          status: status,
          duration: duration_seconds,
          formats: formats,
          serializers: serializer_versions.keys,
          started_at: started_at,
          completed_at: completed_at
        }
      end

      def fastest_serializer(operation = 'parsing', data_size = 'medium')
        results_for_operation = @results[operation]
        return nil unless results_for_operation

        size_results = results_for_operation[data_size]
        return nil unless size_results

        fastest = nil
        fastest_rate = 0

        size_results.each do |format, serializers|
          serializers.each do |serializer, data|
            next if data['error'] || data['skipped']

            rate = data['iterations_per_second']
            next unless rate && rate > fastest_rate

            fastest_rate = rate
            fastest = {
              serializer: serializer,
              format: format,
              rate: rate
            }
          end
        end

        fastest
      end

      def slowest_serializer(operation = 'parsing', data_size = 'medium')
        results_for_operation = @results[operation]
        return nil unless results_for_operation

        size_results = results_for_operation[data_size]
        return nil unless size_results

        slowest = nil
        slowest_rate = Float::INFINITY

        size_results.each do |format, serializers|
          serializers.each do |serializer, data|
            next if data['error'] || data['skipped']

            rate = data['iterations_per_second']
            next unless rate && rate < slowest_rate

            slowest_rate = rate
            slowest = {
              serializer: serializer,
              format: format,
              rate: rate
            }
          end
        end

        slowest
      end

      private

      def validate!
        raise ArgumentError, 'Result name is required' if @name.nil? || @name.strip.empty?
        raise ArgumentError, 'Environment information is required' unless @environment.is_a?(Hash)
        raise ArgumentError, 'Benchmark configuration is required' unless @benchmark_config.is_a?(Hash)
        raise ArgumentError, 'Execution information is required' unless @execution.is_a?(Hash)
        raise ArgumentError, 'Results data is required' unless @results.is_a?(Hash)
        raise ArgumentError, 'Metadata is required' unless @metadata.is_a?(Hash)

        validate_environment!
        validate_benchmark_config!
        validate_execution!
      end

      def validate_environment!
        required_fields = %w[name type ruby_version platform]
        required_fields.each do |field|
          raise ArgumentError, "Environment missing required field: #{field}" unless @environment[field]
        end

        return if %w[docker asdf local].include?(@environment['type'])

        raise ArgumentError, "Invalid environment type: #{@environment['type']}"
      end

      def validate_benchmark_config!
        required_fields = %w[file_path formats data_sizes iterations]
        required_fields.each do |field|
          raise ArgumentError, "Benchmark config missing required field: #{field}" unless @benchmark_config[field]
        end

        unless @benchmark_config['formats'].is_a?(Array) && !@benchmark_config['formats'].empty?
          raise ArgumentError, 'Benchmark config must specify at least one format'
        end

        return if @benchmark_config['data_sizes'].is_a?(Array) && !@benchmark_config['data_sizes'].empty?

        raise ArgumentError, 'Benchmark config must specify at least one data size'
      end

      def validate_execution!
        raise ArgumentError, 'Execution must have started_at timestamp' unless @execution['started_at']

        return if %w[running success partial failed].include?(@execution['status'])

        raise ArgumentError, "Invalid execution status: #{@execution['status']}"
      end

      def self.environment_info(environment)
        if environment.is_a?(Hash)
          environment
        elsif environment.respond_to?(:to_h)
          env_hash = environment.to_h
          {
            'name' => env_hash['name'],
            'type' => env_hash['type'],
            'ruby_version' => detect_ruby_version,
            'platform' => detect_platform,
            'additional_info' => env_hash.except('name', 'type')
          }
        else
          raise ArgumentError, 'Invalid environment object'
        end
      end

      def self.benchmark_config_info(config)
        if config.is_a?(Hash)
          config
        elsif config.respond_to?(:to_h)
          config.to_h
        else
          raise ArgumentError, 'Invalid benchmark config object'
        end
      end

      def self.detect_ruby_version
        RUBY_VERSION
      end

      def self.detect_platform
        "#{RbConfig::CONFIG['host_cpu']}-#{RbConfig::CONFIG['host_os']}"
      end

      def self.system_info
        {
          'cpu_count' => detect_cpu_count,
          'memory_mb' => detect_memory_mb,
          'os_name' => RbConfig::CONFIG['host_os'],
          'os_version' => detect_os_version
        }
      end

      def self.detect_cpu_count
        require 'etc'
        Etc.nprocessors
      rescue StandardError
        1
      end

      def self.detect_memory_mb
        case RbConfig::CONFIG['host_os']
        when /linux/i
          `/proc/meminfo`.match(/MemTotal:\s+(\d+)\s+kB/i)
          Regexp.last_match(1).to_i / 1024 if Regexp.last_match(1)
        when /darwin/i
          `sysctl -n hw.memsize`.to_i / (1024 * 1024)
        else
          nil
        end
      rescue StandardError
        nil
      end

      def self.detect_os_version
        case RbConfig::CONFIG['host_os']
        when /linux/i
          File.read('/etc/os-release').match(/VERSION="([^"]+)"/i)
          Regexp.last_match(1) if Regexp.last_match(1)
        when /darwin/i
          `sw_vers -productVersion`.strip
        else
          'unknown'
        end
      rescue StandardError
        'unknown'
      end
    end
  end
end
