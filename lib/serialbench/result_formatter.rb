# frozen_string_literal: true

require 'json'
require 'csv'

module Serialbench
  class ResultFormatter
    def initialize(results)
      @results = results
    end

    def to_json(pretty: true)
      if pretty
        JSON.pretty_generate(@results)
      else
        JSON.generate(@results)
      end
    end

    def to_csv
      return '' unless @results && @results[:dom_parsing]

      csv_data = []

      # Header
      csv_data << ['Category', 'File Size', 'Parser', 'Time (ms)', 'Iterations/sec', 'Memory (MB)', 'Error']

      # DOM parsing results
      add_category_to_csv(csv_data, 'DOM Parsing', @results[:dom_parsing])

      # SAX parsing results
      add_category_to_csv(csv_data, 'SAX Parsing', @results[:sax_parsing])

      # XML generation results
      add_category_to_csv(csv_data, 'XML Generation', @results[:xml_generation])

      CSV.generate do |csv|
        csv_data.each { |row| csv << row }
      end
    end

    def save_to_files(output_dir = 'results/data')
      FileUtils.mkdir_p(output_dir)

      # Save JSON
      json_file = File.join(output_dir, 'results.json')
      File.write(json_file, to_json)

      # Save CSV
      csv_file = File.join(output_dir, 'results.csv')
      File.write(csv_file, to_csv)

      {
        json: json_file,
        csv: csv_file
      }
    end

    def summary
      return 'No results available' unless @results

      summary_lines = []
      summary_lines << 'XML Benchmarks Summary'
      summary_lines << '=' * 50

      if @results[:environment]
        summary_lines << "Environment: Ruby #{@results[:environment][:ruby_version]} on #{@results[:environment][:ruby_platform]}"
        summary_lines << "Timestamp: #{@results[:environment][:timestamp]}"
        summary_lines << ''
      end

      # DOM parsing summary
      if @results[:dom_parsing] && !@results[:dom_parsing].empty?
        summary_lines << 'DOM Parsing Performance:'
        add_category_summary(summary_lines, @results[:dom_parsing])
        summary_lines << ''
      end

      # SAX parsing summary
      if @results[:sax_parsing] && !@results[:sax_parsing].empty?
        summary_lines << 'SAX Parsing Performance:'
        add_category_summary(summary_lines, @results[:sax_parsing])
        summary_lines << ''
      end

      # XML generation summary
      if @results[:xml_generation] && !@results[:xml_generation].empty?
        summary_lines << 'XML Generation Performance:'
        add_category_summary(summary_lines, @results[:xml_generation])
        summary_lines << ''
      end

      # Memory usage summary
      if @results[:memory_usage] && !@results[:memory_usage].empty?
        summary_lines << 'Memory Usage:'
        add_memory_summary(summary_lines, @results[:memory_usage])
      end

      summary_lines.join("\n")
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
            parser.capitalize,
            data[:error] ? nil : (data[:time_per_iteration] * 1000).round(2),
            data[:error] ? nil : data[:iterations_per_second].round(2),
            memory_mb,
            data[:error] || nil
          ]
        end
      end
    end

    def add_category_summary(summary_lines, results)
      results.each do |size, parsers|
        summary_lines << "  #{size.to_s.capitalize} files:"

        # Sort parsers by performance (fastest first)
        sorted_parsers = parsers.reject { |_, data| data[:error] }
                                .sort_by { |_, data| data[:time_per_iteration] }

        sorted_parsers.each_with_index do |(parser, data), index|
          time_ms = (data[:time_per_iteration] * 1000).round(2)
          rank = case index
                 when 0 then '🥇'
                 when 1 then '🥈'
                 when 2 then '🥉'
                 else '  '
                 end
          summary_lines << "    #{rank} #{parser.capitalize}: #{time_ms}ms"
        end

        # Show errors if any
        errors = parsers.select { |_, data| data[:error] }
        errors.each do |parser, data|
          summary_lines << "    ❌ #{parser.capitalize}: #{data[:error]}"
        end
      end
    end

    def add_memory_summary(summary_lines, results)
      results.each do |size, parsers|
        summary_lines << "  #{size.to_s.capitalize} files:"

        # Sort parsers by memory usage (lowest first)
        sorted_parsers = parsers.reject { |_, data| data[:error] }
                                .sort_by { |_, data| data[:allocated_memory] }

        sorted_parsers.each_with_index do |(parser, data), index|
          memory_mb = (data[:allocated_memory] / 1024.0 / 1024.0).round(2)
          rank = case index
                 when 0 then '🥇'
                 when 1 then '🥈'
                 when 2 then '🥉'
                 else '  '
                 end
          summary_lines << "    #{rank} #{parser.capitalize}: #{memory_mb}MB"
        end

        # Show errors if any
        errors = parsers.select { |_, data| data[:error] }
        errors.each do |parser, data|
          summary_lines << "    ❌ #{parser.capitalize}: #{data[:error]}"
        end
      end
    end
  end
end
