# frozen_string_literal: true

require 'yaml'
require 'json'
require 'time'

module Serialbench
  class SchemaValidator
    class ValidationError < StandardError; end

    def initialize(schema_path = nil)
      @schema_path = schema_path || File.join(__dir__, '../../docs/benchmark_schema.yaml')
      @schema = load_schema
    end

    def validate_single_benchmark(data)
      errors = []

      # Validate required top-level fields
      errors.concat(validate_required_fields(data, %w[environment parsing ruby_version ruby_platform timestamp]))

      # Validate environment
      env_data = data['environment'] || data[:environment]
      if env_data
        errors.concat(validate_environment(env_data))
      end

      # Validate operations
      %w[parsing generation memory streaming].each do |operation|
        operation_data = data[operation] || data[operation.to_sym]
        next unless operation_data

        if operation == 'memory'
          errors.concat(validate_memory_operation(operation_data, operation))
        else
          errors.concat(validate_operation(operation_data, operation))
        end
      end

      # Validate metadata consistency
      errors.concat(validate_metadata_consistency(data))

      # Validate performance calculations
      errors.concat(validate_performance_calculations(data))

      if errors.any?
        raise ValidationError, "Validation failed:\n#{errors.join("\n")}"
      end

      true
    end

    def validate_merged_benchmark(data)
      errors = []

      # Validate required top-level fields for merged results
      errors.concat(validate_required_fields(data, %w[combined_results environments metadata]))

      # Validate environments section
      if data['environments']
        errors.concat(validate_environments_section(data['environments']))
      end

      # Validate metadata section
      if data['metadata']
        errors.concat(validate_metadata_section(data['metadata']))
      end

      # Validate combined results
      if data['combined_results']
        errors.concat(validate_combined_results(data['combined_results'], data['environments']))
      end

      if errors.any?
        raise ValidationError, "Merged validation failed:\n#{errors.join("\n")}"
      end

      true
    end

    def validate_file(file_path)
      unless File.exist?(file_path)
        raise ValidationError, "File not found: #{file_path}"
      end

      begin
        data = case File.extname(file_path).downcase
               when '.json'
                 JSON.parse(File.read(file_path))
               when '.yaml', '.yml'
                 YAML.load_file(file_path)
               else
                 raise ValidationError, "Unsupported file format: #{File.extname(file_path)}"
               end

        # Determine if this is a single or merged benchmark result
        if data['combined_results'] && data['environments']
          validate_merged_benchmark(data)
        else
          validate_single_benchmark(data)
        end
      rescue JSON::ParserError => e
        raise ValidationError, "Invalid JSON: #{e.message}"
      rescue Psych::SyntaxError => e
        raise ValidationError, "Invalid YAML: #{e.message}"
      end
    end

    def validate_directory(directory_path, pattern = '**/results.{json,yaml,yml}')
      unless Dir.exist?(directory_path)
        raise ValidationError, "Directory not found: #{directory_path}"
      end

      files = Dir.glob(File.join(directory_path, pattern))

      if files.empty?
        raise ValidationError, "No benchmark result files found in: #{directory_path}"
      end

      results = {
        total_files: files.length,
        valid_files: [],
        invalid_files: [],
        errors: {}
      }

      files.each do |file|
        begin
          validate_file(file)
          results[:valid_files] << file
        rescue ValidationError => e
          results[:invalid_files] << file
          results[:errors][file] = e.message
        end
      end

      results
    end

    private

    def load_schema
      unless File.exist?(@schema_path)
        raise ValidationError, "Schema file not found: #{@schema_path}"
      end

      YAML.load_file(@schema_path)
    rescue Psych::SyntaxError => e
      raise ValidationError, "Invalid schema YAML: #{e.message}"
    end

    def validate_required_fields(data, required_fields)
      errors = []
      required_fields.each do |field|
        # Check both string and symbol keys for YAML compatibility
        unless (data.key?(field) || data.key?(field.to_sym)) &&
               (!data[field].nil? || !data[field.to_sym].nil?)
          errors << "Missing required field: #{field}"
        end
      end
      errors
    end

    def validate_environment(env_data)
      errors = []

      # Required environment fields
      required_fields = %w[ruby_version ruby_platform serializer_versions timestamp]
      errors.concat(validate_required_fields(env_data, required_fields))

      # Validate Ruby version format
      if env_data['ruby_version']
        unless env_data['ruby_version'].match?(/^\d+\.\d+\.\d+$/)
          errors << "Invalid ruby_version format: #{env_data['ruby_version']} (expected: major.minor.patch)"
        end
      end

      # Validate platform
      if env_data['ruby_platform']
        valid_platforms = %w[aarch64-linux x86_64-linux x86_64-darwin aarch64-darwin x86_64-mingw32]
        unless valid_platforms.include?(env_data['ruby_platform'])
          errors << "Invalid ruby_platform: #{env_data['ruby_platform']} (valid: #{valid_platforms.join(', ')})"
        end
      end

      # Validate timestamp
      if env_data['timestamp']
        begin
          Time.parse(env_data['timestamp'])
        rescue ArgumentError
          errors << "Invalid timestamp format: #{env_data['timestamp']} (expected: ISO 8601)"
        end
      end

      # Validate serializer versions
      if env_data['serializer_versions']
        unless env_data['serializer_versions'].is_a?(Hash)
          errors << "serializer_versions must be a hash"
        end
      end

      errors
    end

    def validate_operation(operation_data, operation_name)
      errors = []

      unless operation_data.is_a?(Hash)
        errors << "#{operation_name} must be a hash"
        return errors
      end

      # Validate size levels
      %w[small medium large].each do |size|
        size_data = operation_data[size] || operation_data[size.to_sym]
        next unless size_data

        errors.concat(validate_size_results(size_data, "#{operation_name}.#{size}"))
      end

      errors
    end

    def validate_memory_operation(memory_data, operation_name)
      errors = []

      unless memory_data.is_a?(Hash)
        errors << "#{operation_name} must be a hash"
        return errors
      end

      # Validate size levels for memory
      %w[small medium large].each do |size|
        next unless memory_data[size]

        errors.concat(validate_memory_size_results(memory_data[size], "#{operation_name}.#{size}"))
      end

      errors
    end

    def validate_size_results(size_data, path)
      errors = []

      unless size_data.is_a?(Hash)
        errors << "#{path} must be a hash"
        return errors
      end

      # Validate format levels
      %w[xml json yaml toml].each do |format|
        format_data = size_data[format] || size_data[format.to_sym]
        next unless format_data

        errors.concat(validate_format_results(format_data, "#{path}.#{format}"))
      end

      errors
    end

    def validate_memory_size_results(size_data, path)
      errors = []

      unless size_data.is_a?(Hash)
        errors << "#{path} must be a hash"
        return errors
      end

      # Validate format levels for memory
      %w[xml json yaml toml].each do |format|
        next unless size_data[format]

        errors.concat(validate_memory_format_results(size_data[format], "#{path}.#{format}"))
      end

      errors
    end

    def validate_format_results(format_data, path)
      errors = []

      unless format_data.is_a?(Hash)
        errors << "#{path} must be a hash"
        return errors
      end

      format_data.each do |serializer, serializer_data|
        errors.concat(validate_serializer_performance(serializer_data, "#{path}.#{serializer}"))
      end

      errors
    end

    def validate_memory_format_results(format_data, path)
      errors = []

      unless format_data.is_a?(Hash)
        errors << "#{path} must be a hash"
        return errors
      end

      format_data.each do |serializer, serializer_data|
        errors.concat(validate_serializer_memory_performance(serializer_data, "#{path}.#{serializer}"))
      end

      errors
    end

    def validate_serializer_performance(perf_data, path)
      errors = []

      unless perf_data.is_a?(Hash)
        errors << "#{path} must be a hash"
        return errors
      end

      # Required performance fields
      required_fields = %w[time_per_iterations time_per_iteration iterations_per_second iterations_count]
      errors.concat(validate_required_fields(perf_data, required_fields))

      # Validate numeric values
      %w[time_per_iterations time_per_iteration iterations_per_second].each do |field|
        if perf_data[field] && !perf_data[field].is_a?(Numeric)
          errors << "#{path}.#{field} must be a number"
        elsif perf_data[field] && perf_data[field] < 0
          errors << "#{path}.#{field} must be non-negative"
        end
      end

      if perf_data['iterations_count'] && !perf_data['iterations_count'].is_a?(Integer)
        errors << "#{path}.iterations_count must be an integer"
      elsif perf_data['iterations_count'] && perf_data['iterations_count'] < 1
        errors << "#{path}.iterations_count must be at least 1"
      end

      errors
    end

    def validate_serializer_memory_performance(mem_data, path)
      errors = []

      unless mem_data.is_a?(Hash)
        errors << "#{path} must be a hash"
        return errors
      end

      # Required memory fields
      required_fields = %w[total_allocated total_retained allocated_memory retained_memory]
      errors.concat(validate_required_fields(mem_data, required_fields))

      # Validate integer values
      required_fields.each do |field|
        if mem_data[field] && !mem_data[field].is_a?(Integer)
          errors << "#{path}.#{field} must be an integer"
        elsif mem_data[field] && mem_data[field] < 0
          errors << "#{path}.#{field} must be non-negative"
        end
      end

      errors
    end

    def validate_metadata_consistency(data)
      errors = []

      # Check consistency between top-level and environment data
      env_data = data['environment'] || data[:environment]
      ruby_version = data['ruby_version'] || data[:ruby_version]
      ruby_platform = data['ruby_platform'] || data[:ruby_platform]

      if env_data && ruby_version
        env_ruby_version = env_data['ruby_version'] || env_data[:ruby_version]
        if env_ruby_version != ruby_version
          errors << "Inconsistent ruby_version: environment.ruby_version (#{env_ruby_version}) != ruby_version (#{ruby_version})"
        end
      end

      if env_data && ruby_platform
        env_ruby_platform = env_data['ruby_platform'] || env_data[:ruby_platform]
        if env_ruby_platform != ruby_platform
          errors << "Inconsistent ruby_platform: environment.ruby_platform (#{env_ruby_platform}) != ruby_platform (#{ruby_platform})"
        end
      end

      errors
    end

    def validate_performance_calculations(data)
      errors = []

      # Validate performance calculation consistency
      %w[parsing generation streaming].each do |operation|
        next unless data[operation]

        data[operation].each do |size, size_data|
          size_data.each do |format, format_data|
            format_data.each do |serializer, perf_data|
              next unless perf_data.is_a?(Hash)

              path = "#{operation}.#{size}.#{format}.#{serializer}"

              # Check iterations_per_second calculation
              if perf_data['time_per_iteration'] && perf_data['iterations_per_second']
                expected_ips = 1.0 / perf_data['time_per_iteration']
                actual_ips = perf_data['iterations_per_second']

                # Allow for floating point precision differences
                if (expected_ips - actual_ips).abs > 0.01
                  errors << "#{path}: iterations_per_second (#{actual_ips}) doesn't match 1/time_per_iteration (#{expected_ips})"
                end
              end

              # Check time_per_iteration calculation
              if perf_data['time_per_iterations'] && perf_data['iterations_count'] && perf_data['time_per_iteration']
                expected_tpi = perf_data['time_per_iterations'] / perf_data['iterations_count']
                actual_tpi = perf_data['time_per_iteration']

                # Allow for floating point precision differences
                if (expected_tpi - actual_tpi).abs > 0.000001
                  errors << "#{path}: time_per_iteration (#{actual_tpi}) doesn't match time_per_iterations/iterations_count (#{expected_tpi})"
                end
              end
            end
          end
        end
      end

      errors
    end

    def validate_environments_section(environments)
      errors = []

      unless environments.is_a?(Hash)
        errors << "environments must be a hash"
        return errors
      end

      environments.each do |env_id, env_data|
        unless env_id.match?(/^[a-zA-Z0-9_-]+$/)
          errors << "Invalid environment ID format: #{env_id} (must match ^[a-zA-Z0-9_-]+$)"
        end

        required_fields = %w[ruby_version ruby_platform source_file timestamp]
        errors.concat(validate_required_fields(env_data, required_fields))

        if env_data['environment']
          errors.concat(validate_environment(env_data['environment']))
        end
      end

      errors
    end

    def validate_metadata_section(metadata)
      errors = []

      required_fields = %w[merged_at ruby_versions platforms]
      errors.concat(validate_required_fields(metadata, required_fields))

      # Validate merged_at timestamp
      merged_at = metadata['merged_at'] || metadata[:merged_at]
      if merged_at
        begin
          Time.parse(merged_at)
        rescue ArgumentError
          errors << "Invalid metadata merged_at format: #{merged_at}"
        end
      end

      # Validate arrays
      %w[ruby_versions platforms].each do |field|
        field_data = metadata[field] || metadata[field.to_sym]
        if field_data && !field_data.is_a?(Array)
          errors << "metadata.#{field} must be an array"
        end
      end

      errors
    end

    def validate_combined_results(combined_results, environments)
      errors = []

      unless combined_results.is_a?(Hash)
        errors << "combined_results must be a hash"
        return errors
      end

      env_ids = environments&.keys || []

      %w[parsing generation memory streaming].each do |operation|
        next unless combined_results[operation]

        errors.concat(validate_merged_operation_results(combined_results[operation], env_ids, operation))
      end

      errors
    end

    def validate_merged_operation_results(operation_data, env_ids, operation_name)
      errors = []

      %w[small medium large].each do |size|
        next unless operation_data[size]

        operation_data[size].each do |format, format_data|
          format_data.each do |serializer, serializer_envs|
            unless serializer_envs.is_a?(Hash)
              errors << "#{operation_name}.#{size}.#{format}.#{serializer} must be a hash of environments"
              next
            end

            serializer_envs.each do |env_id, perf_data|
              unless env_ids.include?(env_id)
                errors << "#{operation_name}.#{size}.#{format}.#{serializer}.#{env_id}: environment ID not found in environments section"
              end

              if operation_name == 'memory'
                errors.concat(validate_serializer_memory_performance(perf_data, "#{operation_name}.#{size}.#{format}.#{serializer}.#{env_id}"))
              else
                errors.concat(validate_serializer_performance(perf_data, "#{operation_name}.#{size}.#{format}.#{serializer}.#{env_id}"))
              end
            end
          end
        end
      end

      errors
    end
  end
end
