# frozen_string_literal: true

require 'json'
require 'yaml'
require 'csv'
require 'fileutils'
require_relative 'template_renderer'
require_relative 'models'

module Serialbench
  class ResultFormatter
    def initialize(results)
      @results = results
      @model = if results.is_a?(Hash)
                 Serialbench::Models.from_data(results)
               else
                 results
               end
    end

    def to_json(pretty: true)
      if @model.respond_to?(:to_json)
        @model.to_json
      elsif pretty
        JSON.pretty_generate(@results)
      else
        JSON.generate(@results)
      end
    end

    def to_yaml
      if @model.respond_to?(:to_yaml)
        @model.to_yaml
      else
        @results.to_yaml
      end
    end

    def to_csv
      return '' unless @results && (@results[:dom_parsing] || @results['parsing'])

      csv_data = []

      # Header
      csv_data << ['Category', 'File Size', 'Parser', 'Time (ms)', 'Iterations/sec', 'Memory (MB)', 'Error']

      # Handle both old and new result formats
      if @results[:dom_parsing]
        # Legacy format
        add_category_to_csv(csv_data, 'DOM Parsing', @results[:dom_parsing])
        add_category_to_csv(csv_data, 'SAX Parsing', @results[:sax_parsing])
        add_category_to_csv(csv_data, 'XML Generation', @results[:xml_generation])
      else
        # New format
        add_new_format_to_csv(csv_data, 'Parsing', @results['parsing'] || @results[:parsing])
        add_new_format_to_csv(csv_data, 'Generation', @results['generation'] || @results[:generation])
        add_new_format_to_csv(csv_data, 'Streaming', @results['streaming'] || @results[:streaming])
      end

      CSV.generate do |csv|
        csv_data.each { |row| csv << row }
      end
    end

    def to_html(output_dir = 'results')
      renderer = TemplateRenderer.new
      renderer.render_single_benchmark(@results, output_dir)
      File.join(output_dir, 'benchmark_report.html')
    end

    def save_to_files(output_dir = 'results')
      data_dir = File.join(output_dir, 'data')
      FileUtils.mkdir_p(data_dir)

      # Primary format: YAML
      yaml_file = File.join(data_dir, 'results.yaml')
      if @model.respond_to?(:to_yaml_file)
        @model.to_yaml_file(yaml_file)
      else
        File.write(yaml_file, to_yaml)
      end

      # Secondary format: JSON (for HTML templates)
      json_file = File.join(data_dir, 'results.json')
      if @model.respond_to?(:to_json_file)
        @model.to_json_file(json_file)
      else
        File.write(json_file, to_json)
      end

      # CSV export
      csv_file = File.join(data_dir, 'results.csv')
      File.write(csv_file, to_csv)

      # HTML report
      html_file = to_html(output_dir)

      puts "Results saved to:"
      puts "  YAML: #{yaml_file}"
      puts "  JSON: #{json_file}"
      puts "  CSV: #{csv_file}"
      puts "  HTML: #{html_file}"

      {
        yaml: yaml_file,
        json: json_file,
        csv: csv_file,
        html: html_file
      }
    end

    def summary
      return 'No results available' unless @results

      summary_lines = []
      summary_lines << 'Serialization Benchmarks Summary'
      summary_lines << '=' * 50

      # Environment info
      env = @results[:environment] || @results['environment']
      if env
        ruby_version = env[:ruby_version] || env['ruby_version']
        ruby_platform = env[:ruby_platform] || env['ruby_platform']
        timestamp = env[:timestamp] || env['timestamp']

        summary_lines << "Environment: Ruby #{ruby_version} on #{ruby_platform}"
        summary_lines << "Timestamp: #{timestamp}"
        summary_lines << ''
      end

      # Performance summaries for each operation
      %w[parsing generation streaming].each do |operation|
        operation_data = @results[operation] || @results[operation.to_sym]
        next unless operation_data && !operation_data.empty?

        summary_lines << "#{operation.capitalize} Performance:"
        add_operation_summary(summary_lines, operation_data)
        summary_lines << ''
      end

      # Memory usage summary
      memory_data = @results[:memory] || @results['memory']
      if memory_data && !memory_data.empty?
        summary_lines << 'Memory Usage:'
        add_memory_operation_summary(summary_lines, memory_data)
      end

      summary_lines.join("\n")
    end

    def validate!
      if @model.respond_to?(:validate!)
        @model.validate!
      else
        # Fallback validation for legacy format
        validator = Serialbench::SchemaValidator.new
        validator.validate_single_benchmark(@results)
      end
    end

    def valid?
      validate!
      true
    rescue Serialbench::SchemaValidator::ValidationError
      false
    end

    private

    def add_category_to_csv(csv_data, category, results)
      return unless results

      results.each do |size, parsers|
        parsers.each do |parser, data|
          memory_mb = if @results[:memory_usage] && @results[:memory_usage][size] && @results[:memory_usage][size][parser]
                        (@results[:memory_usage][size][parser][:allocated_memory] / 1024.0 / 1024.0).round(2)
                      else
                        nil
                      end

          csv_data << [
            category,
            size.to_s.capitalize,
            parser.to_s.capitalize,
            data[:error] ? nil : (data[:time_per_iteration] * 1000).round(2),
            data[:error] ? nil : data[:iterations_per_second].round(2),
            memory_mb,
            data[:error] || nil
          ]
        end
      end
    end

    def add_new_format_to_csv(csv_data, category, results)
      return unless results

      results.each do |size, size_data|
        size_data.each do |format, format_data|
          format_data.each do |serializer, perf_data|
            csv_data << [
              "#{category} (#{format.upcase})",
              size.to_s.capitalize,
              serializer.to_s.capitalize,
              perf_data['error'] ? nil : (perf_data['time_per_iteration'] * 1000).round(2),
              perf_data['error'] ? nil : perf_data['iterations_per_second'].round(2),
              nil, # Memory data handled separately
              perf_data['error'] || nil
            ]
          end
        end
      end
    end

    def add_operation_summary(summary_lines, operation_data)
      operation_data.each do |size, size_data|
        summary_lines << "  #{size.to_s.capitalize} files:"

        size_data.each do |format, format_data|
          summary_lines << "    #{format.upcase}:"

          # Sort serializers by performance (fastest first)
          sorted_serializers = format_data.reject { |_, data| data['error'] || data[:error] }
                                          .sort_by { |_, data| data['time_per_iteration'] || data[:time_per_iteration] }

          sorted_serializers.each_with_index do |(serializer, data), index|
            time_per_iter = data['time_per_iteration'] || data[:time_per_iteration]
            time_ms = (time_per_iter * 1000).round(2)
            rank = case index
                   when 0 then '🥇'
                   when 1 then '🥈'
                   when 2 then '🥉'
                   else '  '
                   end
            summary_lines << "      #{rank} #{serializer.to_s.capitalize}: #{time_ms}ms"
          end

          # Show errors if any
          errors = format_data.select { |_, data| data['error'] || data[:error] }
          errors.each do |serializer, data|
            error_msg = data['error'] || data[:error]
            summary_lines << "      ❌ #{serializer.to_s.capitalize}: #{error_msg}"
          end
        end
      end
    end

    def add_memory_operation_summary(summary_lines, memory_data)
      memory_data.each do |size, size_data|
        summary_lines << "  #{size.to_s.capitalize} files:"

        size_data.each do |format, format_data|
          summary_lines << "    #{format.upcase}:"

          # Sort serializers by memory usage (lowest first)
          sorted_serializers = format_data.reject { |_, data| data['error'] || data[:error] }
                                          .sort_by { |_, data| data['allocated_memory'] || data[:allocated_memory] }

          sorted_serializers.each_with_index do |(serializer, data), index|
            allocated = data['allocated_memory'] || data[:allocated_memory]
            memory_mb = (allocated / 1024.0 / 1024.0).round(2)
            rank = case index
                   when 0 then '🥇'
                   when 1 then '🥈'
                   when 2 then '🥉'
                   else '  '
                   end
            summary_lines << "      #{rank} #{serializer.to_s.capitalize}: #{memory_mb}MB"
          end

          # Show errors if any
          errors = format_data.select { |_, data| data['error'] || data[:error] }
          errors.each do |serializer, data|
            error_msg = data['error'] || data[:error]
            summary_lines << "      ❌ #{serializer.to_s.capitalize}: #{error_msg}"
          end
        end
      end
    end
  end
end
