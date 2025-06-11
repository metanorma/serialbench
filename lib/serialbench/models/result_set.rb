# frozen_string_literal: true

require 'yaml'
require 'time'
require 'fileutils'

module Serialbench
  module Models
    # ResultSet model for managing collections of benchmark results
    class ResultSet
      attr_reader :name, :description, :created_at, :updated_at, :results, :comparison, :aggregation, :metadata

      def initialize(config_hash)
        @config = config_hash.dup
        @name = config_hash['name']
        @description = config_hash['description']
        @created_at = Time.parse(config_hash['created_at']) if config_hash['created_at']
        @updated_at = Time.parse(config_hash['updated_at']) if config_hash['updated_at']
        @results = config_hash['results'] || []
        @comparison = config_hash['comparison'] || {}
        @aggregation = config_hash['aggregation'] || {}
        @metadata = config_hash['metadata'] || {}

        validate!
      end

      def self.load_from_file(file_path)
        config = YAML.load_file(file_path)
        new(config)
      rescue StandardError => e
        raise "Failed to load resultset from #{file_path}: #{e.message}"
      end

      def self.load_from_directory(resultset_dir)
        resultset_file = File.join(resultset_dir, 'resultset.yml')
        raise "ResultSet file not found: #{resultset_file}" unless File.exist?(resultset_file)

        load_from_file(resultset_file)
      end

      def self.create(name, options = {})
        config = {
          'name' => name,
          'description' => options[:description],
          'created_at' => Time.now.iso8601,
          'updated_at' => Time.now.iso8601,
          'results' => [],
          'comparison' => {
            'grouping' => options[:grouping] || 'environment'
          },
          'aggregation' => {},
          'metadata' => {
            'created_by' => 'serialbench-cli',
            'purpose' => options[:purpose],
            'tags' => options[:tags] || [],
            'site_config' => {
              'template' => 'comparison',
              'theme' => 'default',
              'include_memory' => false,
              'include_charts' => true
            }
          }
        }.compact

        new(config)
      end

      def save_to_directory(resultset_dir)
        FileUtils.mkdir_p(resultset_dir)
        resultset_file = File.join(resultset_dir, 'resultset.yml')
        File.write(resultset_file, @config.to_yaml)
        resultset_file
      end

      def save_to_file(file_path)
        File.write(file_path, @config.to_yaml)
      end

      def add_result(result_name, result_path, options = {})
        # Check if result already exists
        existing = @results.find { |r| r['name'] == result_name }
        raise ArgumentError, "Result '#{result_name}' already exists in this resultset" if existing

        # Validate that the result path exists
        raise ArgumentError, "Result directory not found: #{result_path}" unless Dir.exist?(result_path)

        result_entry = {
          'name' => result_name,
          'path' => result_path,
          'added_at' => Time.now.iso8601,
          'tags' => options[:tags] || [],
          'notes' => options[:notes]
        }.compact

        @results << result_entry
        @config['results'] = @results
        @config['updated_at'] = Time.now.iso8601
        @updated_at = Time.now

        # Regenerate aggregation data
        regenerate_aggregation!

        result_entry
      end

      def remove_result(result_name)
        removed = @results.reject! { |r| r['name'] == result_name }
        if removed
          @config['results'] = @results
          @config['updated_at'] = Time.now.iso8601
          @updated_at = Time.now
          regenerate_aggregation!
          true
        else
          false
        end
      end

      def result_names
        @results.map { |r| r['name'] }
      end

      def result_paths
        @results.map { |r| r['path'] }
      end

      def result_count
        @results.length
      end

      def empty?
        @results.empty?
      end

      def baseline
        @comparison['baseline']
      end

      def baseline=(result_name)
        unless result_names.include?(result_name)
          raise ArgumentError, "Result '#{result_name}' is not in this resultset"
        end

        @comparison['baseline'] = result_name
        @config['comparison']['baseline'] = result_name
        @config['updated_at'] = Time.now.iso8601
        @updated_at = Time.now
      end

      def grouping
        @comparison['grouping'] || 'environment'
      end

      def grouping=(value)
        valid_groupings = %w[environment format data_size serializer]
        unless valid_groupings.include?(value)
          raise ArgumentError, "Invalid grouping: #{value}. Must be one of: #{valid_groupings.join(', ')}"
        end

        @comparison['grouping'] = value
        @config['comparison']['grouping'] = value
        @config['updated_at'] = Time.now.iso8601
        @updated_at = Time.now
      end

      def filters
        @comparison['filters'] || {}
      end

      def set_filters(filters_hash)
        @comparison['filters'] = filters_hash
        @config['comparison']['filters'] = filters_hash
        @config['updated_at'] = Time.now.iso8601
        @updated_at = Time.now
      end

      def tags
        @metadata['tags'] || []
      end

      def add_tag(tag)
        current_tags = tags
        return if current_tags.include?(tag)

        current_tags << tag
        @metadata['tags'] = current_tags
        @config['metadata']['tags'] = current_tags
        @config['updated_at'] = Time.now.iso8601
        @updated_at = Time.now
      end

      def remove_tag(tag)
        current_tags = tags
        if current_tags.delete(tag)
          @metadata['tags'] = current_tags
          @config['metadata']['tags'] = current_tags
          @config['updated_at'] = Time.now.iso8601
          @updated_at = Time.now
          true
        else
          false
        end
      end

      def purpose
        @metadata['purpose']
      end

      def purpose=(value)
        @metadata['purpose'] = value
        @config['metadata']['purpose'] = value
        @config['updated_at'] = Time.now.iso8601
        @updated_at = Time.now
      end

      def site_config
        @metadata['site_config'] || {}
      end

      def update_site_config(config_hash)
        current_config = site_config
        current_config.merge!(config_hash)
        @metadata['site_config'] = current_config
        @config['metadata']['site_config'] = current_config
        @config['updated_at'] = Time.now.iso8601
        @updated_at = Time.now
      end

      # Aggregation data accessors
      def total_results
        @aggregation['total_results'] || 0
      end

      def environments
        @aggregation['environments'] || []
      end

      def formats
        @aggregation['formats'] || []
      end

      def serializers
        @aggregation['serializers'] || []
      end

      def date_range
        @aggregation['date_range'] || {}
      end

      def performance_summary
        @aggregation['performance_summary'] || {}
      end

      def fastest_serializer
        performance_summary['fastest_serializer']
      end

      def slowest_serializer
        performance_summary['slowest_serializer']
      end

      def memory_efficient
        performance_summary['memory_efficient']
      end

      def load_results
        @results.map do |result_entry|
          Models::Result.load_from_directory(result_entry['path'])
        rescue StandardError => e
          warn "Failed to load result #{result_entry['name']}: #{e.message}"
          nil
        end.compact
      end

      def to_h
        @config.dup
      end

      def to_yaml
        @config.to_yaml
      end

      def ==(other)
        other.is_a?(ResultSet) && @config == other.instance_variable_get(:@config)
      end

      def hash
        @config.hash
      end

      def summary
        {
          name: @name,
          description: @description,
          result_count: result_count,
          environments: environments,
          formats: formats,
          created_at: @created_at,
          updated_at: @updated_at,
          baseline: baseline,
          grouping: grouping
        }
      end

      private

      def validate!
        raise ArgumentError, 'ResultSet name is required' if @name.nil? || @name.strip.empty?
        raise ArgumentError, 'Created timestamp is required' unless @created_at
        raise ArgumentError, 'Results must be an array' unless @results.is_a?(Array)
        raise ArgumentError, 'Comparison must be a hash' unless @comparison.is_a?(Hash)
        raise ArgumentError, 'Aggregation must be a hash' unless @aggregation.is_a?(Hash)
        raise ArgumentError, 'Metadata must be a hash' unless @metadata.is_a?(Hash)

        # Validate individual result entries
        @results.each_with_index do |result, index|
          validate_result_entry!(result, index)
        end

        # Validate comparison settings
        validate_comparison!
      end

      def validate_result_entry!(result, index)
        raise ArgumentError, "Result entry #{index} must be a hash" unless result.is_a?(Hash)

        required_fields = %w[name path added_at]
        required_fields.each do |field|
          raise ArgumentError, "Result entry #{index} missing required field: #{field}" unless result[field]
        end

        # Validate timestamp
        begin
          Time.parse(result['added_at'])
        rescue StandardError
          raise ArgumentError, "Result entry #{index} has invalid added_at timestamp"
        end
      end

      def validate_comparison!
        if @comparison['grouping']
          valid_groupings = %w[environment format data_size serializer]
          unless valid_groupings.include?(@comparison['grouping'])
            raise ArgumentError, "Invalid grouping: #{@comparison['grouping']}"
          end
        end

        return unless @comparison['baseline'] && !result_names.include?(@comparison['baseline'])

        raise ArgumentError, "Baseline result '#{@comparison['baseline']}' not found in resultset"
      end

      def regenerate_aggregation!
        loaded_results = load_results
        return if loaded_results.empty?

        # Calculate aggregation data
        all_environments = loaded_results.map(&:environment_name).uniq.sort
        all_formats = loaded_results.flat_map(&:formats).uniq.sort
        all_serializers = loaded_results.flat_map { |r| r.serializer_versions.keys }.uniq.sort

        dates = loaded_results.map(&:started_at).compact
        earliest = dates.min
        latest = dates.max

        # Find performance extremes
        fastest = find_fastest_serializer(loaded_results)
        slowest = find_slowest_serializer(loaded_results)
        memory_efficient = find_memory_efficient_serializer(loaded_results)

        @aggregation = {
          'total_results' => loaded_results.length,
          'environments' => all_environments,
          'formats' => all_formats,
          'serializers' => all_serializers,
          'date_range' => {
            'earliest' => earliest&.iso8601,
            'latest' => latest&.iso8601
          }.compact,
          'performance_summary' => {
            'fastest_serializer' => fastest,
            'slowest_serializer' => slowest,
            'memory_efficient' => memory_efficient
          }.compact
        }

        @config['aggregation'] = @aggregation
      end

      def find_fastest_serializer(results)
        fastest = nil
        fastest_rate = 0

        results.each do |result|
          result.parsing_results.each do |data_size, formats|
            formats.each do |format, serializers|
              serializers.each do |serializer, data|
                next if data['error'] || data['skipped']

                rate = data['iterations_per_second']
                next unless rate && rate > fastest_rate

                fastest_rate = rate
                fastest = {
                  'name' => serializer,
                  'format' => format,
                  'operations_per_second' => rate
                }
              end
            end
          end
        end

        fastest
      end

      def find_slowest_serializer(results)
        slowest = nil
        slowest_rate = Float::INFINITY

        results.each do |result|
          result.parsing_results.each do |data_size, formats|
            formats.each do |format, serializers|
              serializers.each do |serializer, data|
                next if data['error'] || data['skipped']

                rate = data['iterations_per_second']
                next unless rate && rate < slowest_rate

                slowest_rate = rate
                slowest = {
                  'name' => serializer,
                  'format' => format,
                  'operations_per_second' => rate
                }
              end
            end
          end
        end

        slowest
      end

      def find_memory_efficient_serializer(results)
        most_efficient = nil
        lowest_memory = Float::INFINITY

        results.each do |result|
          next unless result.memory_profiling?

          result.memory_results.each do |data_size, formats|
            formats.each do |format, serializers|
              serializers.each do |serializer, data|
                next if data['error'] || data['skipped']

                memory = data['total_allocated_mb']
                next unless memory && memory < lowest_memory

                lowest_memory = memory
                most_efficient = {
                  'name' => serializer,
                  'format' => format,
                  'memory_mb' => memory
                }
              end
            end
          end
        end

        most_efficient
      end
    end
  end
end
