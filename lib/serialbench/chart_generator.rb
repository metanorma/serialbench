# frozen_string_literal: true

module Serialbench
  class ChartGenerator
    COLORS = {
      ox: '#2E8B57',        # Sea Green
      nokogiri: '#4169E1',  # Royal Blue
      libxml: '#DC143C',    # Crimson
      oga: '#FF8C00',       # Dark Orange
      rexml: '#9932CC'      # Dark Orchid
    }.freeze

    def initialize(results)
      @results = results
    end

    def generate_all_charts(output_dir = 'results/charts')
      FileUtils.mkdir_p(output_dir)

      charts = {
        'dom_parsing_performance.svg' => generate_dom_parsing_chart,
        'sax_parsing_performance.svg' => generate_sax_parsing_chart,
        'xml_generation_performance.svg' => generate_xml_generation_chart,
        'memory_usage_comparison.svg' => generate_memory_usage_chart,
        'performance_overview.svg' => generate_overview_chart
      }

      charts.each do |filename, svg_content|
        File.write(File.join(output_dir, filename), svg_content)
      end

      charts.keys
    end

    def generate_multi_version_charts(output_dir = 'results/charts')
      FileUtils.mkdir_p(output_dir)

      charts = {
        'ruby_version_comparison.svg' => generate_ruby_version_comparison_chart,
        'multi_version_overview.svg' => generate_multi_version_overview_chart,
        'dom_parsing_performance.svg' => generate_multi_version_dom_chart,
        'sax_parsing_performance.svg' => generate_multi_version_sax_chart,
        'xml_generation_performance.svg' => generate_multi_version_generation_chart
      }

      charts.each do |filename, svg_content|
        File.write(File.join(output_dir, filename), svg_content)
      end

      charts.keys
    end

    def generate_dom_parsing_chart
      data = extract_performance_data(@results[:dom_parsing])
      create_bar_chart(
        title: 'DOM parsing performance comparison',
        subtitle: 'Time per iteration (lower is better)',
        data: data,
        y_label: 'Time (milliseconds)',
        value_formatter: ->(v) { "#{(v * 1000).round(2)}ms" }
      )
    end

    def generate_sax_parsing_chart
      data = extract_performance_data(@results[:sax_parsing])
      create_bar_chart(
        title: 'SAX parsing performance comparison',
        subtitle: 'Time per iteration (lower is better)',
        data: data,
        y_label: 'Time (milliseconds)',
        value_formatter: ->(v) { "#{(v * 1000).round(2)}ms" }
      )
    end

    def generate_xml_generation_chart
      data = extract_performance_data(@results[:xml_generation])
      create_bar_chart(
        title: 'XML generation performance comparison',
        subtitle: 'Time per iteration (lower is better)',
        data: data,
        y_label: 'Time (milliseconds)',
        value_formatter: ->(v) { "#{(v * 1000).round(2)}ms" }
      )
    end

    def generate_memory_usage_chart
      return create_empty_chart('Memory usage data not available') unless @results[:memory_usage]

      data = extract_memory_data(@results[:memory_usage])
      create_bar_chart(
        title: 'Memory usage comparison',
        subtitle: 'Allocated memory (lower is better)',
        data: data,
        y_label: 'Memory (MB)',
        value_formatter: ->(v) { "#{(v / 1024.0 / 1024.0).round(2)}MB" }
      )
    end

    def generate_overview_chart
      # Create a radar chart showing relative performance across all metrics
      create_radar_chart
    end

    private

    def extract_performance_data(benchmark_results)
      return {} unless benchmark_results

      data = {}
      benchmark_results.each do |size, parsers|
        data[size] = {}
        parsers.each do |parser, results|
          next if results[:error]

          data[size][parser] = results[:time_per_iteration]
        end
      end
      data
    end

    def extract_memory_data(memory_results)
      return {} unless memory_results

      data = {}
      memory_results.each do |size, parsers|
        data[size] = {}
        parsers.each do |parser, results|
          next if results[:error]

          data[size][parser] = results[:allocated_memory]
        end
      end
      data
    end

    def create_bar_chart(title:, subtitle:, data:, y_label:, value_formatter:)
      return create_empty_chart('No data available') if data.empty?

      width = 800
      height = 600
      margin = { top: 80, right: 50, bottom: 100, left: 80 }
      chart_width = width - margin[:left] - margin[:right]
      chart_height = height - margin[:top] - margin[:bottom]

      # Prepare data for charting
      sizes = data.keys
      parsers = data.values.flat_map(&:keys).uniq
      max_value = data.values.flat_map(&:values).compact.max || 1

      # Calculate bar dimensions
      group_width = chart_width / sizes.length.to_f
      bar_width = (group_width * 0.8) / parsers.length.to_f
      bar_spacing = group_width * 0.1

      <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="#{width}" height="#{height}" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <style>
              .chart-title { font-family: Arial, sans-serif; font-size: 20px; font-weight: bold; text-anchor: middle; }
              .chart-subtitle { font-family: Arial, sans-serif; font-size: 14px; text-anchor: middle; fill: #666; }
              .axis-label { font-family: Arial, sans-serif; font-size: 12px; text-anchor: middle; }
              .tick-label { font-family: Arial, sans-serif; font-size: 10px; text-anchor: middle; }
              .legend-text { font-family: Arial, sans-serif; font-size: 11px; }
              .bar { stroke: none; }
              .bar:hover { opacity: 0.8; }
              .grid-line { stroke: #e0e0e0; stroke-width: 1; }
              .axis-line { stroke: #333; stroke-width: 2; }
            </style>
          </defs>

          <!-- Background -->
          <rect width="#{width}" height="#{height}" fill="white"/>

          <!-- Title -->
          <text x="#{width / 2}" y="30" class="chart-title">#{title}</text>
          <text x="#{width / 2}" y="50" class="chart-subtitle">#{subtitle}</text>

          <!-- Chart area -->
          <g transform="translate(#{margin[:left]}, #{margin[:top]})">
            <!-- Grid lines -->
            #{generate_grid_lines(chart_height, max_value, 5)}

            <!-- Bars -->
            #{generate_bars(data, sizes, parsers, chart_height, max_value, group_width, bar_width, bar_spacing)}

            <!-- Axes -->
            <line x1="0" y1="#{chart_height}" x2="#{chart_width}" y2="#{chart_height}" class="axis-line"/>
            <line x1="0" y1="0" x2="0" y2="#{chart_height}" class="axis-line"/>

            <!-- Y-axis labels -->
            #{generate_y_axis_labels(chart_height, max_value, 5, value_formatter)}

            <!-- X-axis labels -->
            #{generate_x_axis_labels(sizes, chart_width, chart_height)}

            <!-- Y-axis title -->
            <text x="-40" y="#{chart_height / 2}" class="axis-label" transform="rotate(-90, -40, #{chart_height / 2})">#{y_label}</text>
          </g>

          <!-- Legend -->
          #{generate_legend(parsers, width, height, margin)}
        </svg>
      SVG
    end

    def generate_grid_lines(chart_height, max_value, num_ticks)
      lines = []
      (0..num_ticks).each do |i|
        y = chart_height - (i * chart_height / num_ticks.to_f)
        lines << %(<line x1="0" y1="#{y}" x2="100%" y2="#{y}" class="grid-line"/>)
      end
      lines.join("\n")
    end

    def generate_bars(data, sizes, parsers, chart_height, max_value, group_width, bar_width, bar_spacing)
      bars = []

      sizes.each_with_index do |size, size_index|
        group_x = size_index * group_width + bar_spacing / 2

        parsers.each_with_index do |parser, parser_index|
          value = data[size][parser] || 0
          next if value == 0

          bar_height = (value / max_value.to_f) * chart_height
          bar_x = group_x + parser_index * bar_width
          bar_y = chart_height - bar_height

          color = COLORS[parser.to_sym] || '#999999'

          bars << <<~BAR
            <rect x="#{bar_x}" y="#{bar_y}" width="#{bar_width}" height="#{bar_height}"
                  fill="#{color}" class="bar">
              <title>#{parser} (#{size}): #{value}</title>
            </rect>
          BAR
        end
      end

      bars.join("\n")
    end

    def generate_y_axis_labels(chart_height, max_value, num_ticks, value_formatter)
      labels = []
      (0..num_ticks).each do |i|
        value = (i * max_value / num_ticks.to_f)
        y = chart_height - (i * chart_height / num_ticks.to_f)
        formatted_value = value_formatter.call(value)
        labels << %(<text x="-10" y="#{y + 4}" class="tick-label" text-anchor="end">#{formatted_value}</text>)
      end
      labels.join("\n")
    end

    def generate_x_axis_labels(sizes, chart_width, chart_height)
      labels = []
      sizes.each_with_index do |size, index|
        x = (index + 0.5) * (chart_width / sizes.length.to_f)
        labels << %(<text x="#{x}" y="#{chart_height + 20}" class="tick-label">#{size.to_s.capitalize}</text>)
      end
      labels.join("\n")
    end

    def generate_legend(parsers, width, height, margin)
      legend_x = width - margin[:right] - 150
      legend_y = margin[:top] + 20

      legend_items = []
      parsers.each_with_index do |parser, index|
        y = legend_y + index * 20
        color = COLORS[parser.to_sym] || '#999999'

        legend_items << <<~ITEM
          <rect x="#{legend_x}" y="#{y - 8}" width="12" height="12" fill="#{color}"/>
          <text x="#{legend_x + 18}" y="#{y + 2}" class="legend-text">#{parser.capitalize}</text>
        ITEM
      end

      legend_items.join("\n")
    end

    def create_radar_chart
      # Simplified radar chart for overview
      parsers = @results[:dom_parsing]&.values&.first&.keys || []
      return create_empty_chart('No data for overview') if parsers.empty?

      width = 600
      height = 600
      center_x = width / 2
      center_y = height / 2
      radius = 200

      # Calculate relative scores for each parser across all metrics
      scores = calculate_relative_scores(parsers)

      <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="#{width}" height="#{height}" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <style>
              .chart-title { font-family: Arial, sans-serif; font-size: 18px; font-weight: bold; text-anchor: middle; }
              .radar-grid { stroke: #ddd; stroke-width: 1; fill: none; }
              .radar-line { stroke-width: 2; fill: none; opacity: 0.8; }
              .radar-area { opacity: 0.3; }
              .axis-label { font-family: Arial, sans-serif; font-size: 12px; text-anchor: middle; }
            </style>
          </defs>

          <!-- Background -->
          <rect width="#{width}" height="#{height}" fill="white"/>

          <!-- Title -->
          <text x="#{center_x}" y="30" class="chart-title">Performance overview (relative scores)</text>

          <!-- Radar grid -->
          #{generate_radar_grid(center_x, center_y, radius)}

          <!-- Radar areas for each parser -->
          #{generate_radar_areas(scores, center_x, center_y, radius)}

          <!-- Axis labels -->
          #{generate_radar_labels(center_x, center_y, radius)}
        </svg>
      SVG
    end

    def generate_radar_grid(center_x, center_y, radius)
      grid = []

      # Concentric circles
      (1..5).each do |i|
        r = radius * i / 5.0
        grid << %(<circle cx="#{center_x}" cy="#{center_y}" r="#{r}" class="radar-grid"/>)
      end

      # Radial lines
      metrics = ['DOM Parse', 'SAX Parse', 'XML Gen', 'Memory']
      metrics.each_with_index do |_, index|
        angle = (index * 2 * Math::PI / metrics.length) - Math::PI / 2
        x = center_x + radius * Math.cos(angle)
        y = center_y + radius * Math.sin(angle)
        grid << %(<line x1="#{center_x}" y1="#{center_y}" x2="#{x}" y2="#{y}" class="radar-grid"/>)
      end

      grid.join("\n")
    end

    def generate_radar_areas(scores, center_x, center_y, radius)
      areas = []

      scores.each do |parser, parser_scores|
        color = COLORS[parser.to_sym] || '#999999'
        points = []

        parser_scores.each_with_index do |score, index|
          angle = (index * 2 * Math::PI / parser_scores.length) - Math::PI / 2
          r = radius * score
          x = center_x + r * Math.cos(angle)
          y = center_y + r * Math.sin(angle)
          points << "#{x},#{y}"
        end

        areas << <<~AREA
          <polygon points="#{points.join(' ')}" fill="#{color}" class="radar-area"/>
          <polygon points="#{points.join(' ')}" stroke="#{color}" class="radar-line"/>
        AREA
      end

      areas.join("\n")
    end

    def generate_radar_labels(center_x, center_y, radius)
      labels = []
      metrics = ['DOM parsing', 'SAX parsing', 'XML generation', 'Memory efficiency']

      metrics.each_with_index do |metric, index|
        angle = (index * 2 * Math::PI / metrics.length) - Math::PI / 2
        x = center_x + (radius + 30) * Math.cos(angle)
        y = center_y + (radius + 30) * Math.sin(angle)
        labels << %(<text x="#{x}" y="#{y}" class="axis-label">#{metric}</text>)
      end

      labels.join("\n")
    end

    def calculate_relative_scores(parsers)
      scores = {}

      parsers.each do |parser|
        # Calculate relative performance scores (higher is better)
        dom_score = calculate_performance_score(parser, @results[:dom_parsing])
        sax_score = calculate_performance_score(parser, @results[:sax_parsing])
        gen_score = calculate_performance_score(parser, @results[:xml_generation])
        mem_score = calculate_memory_score(parser, @results[:memory_usage])

        scores[parser] = [dom_score, sax_score, gen_score, mem_score]
      end

      scores
    end

    def calculate_performance_score(parser, results)
      return 0.5 unless results

      # Average performance across all test sizes (inverted - lower time = higher score)
      times = results.values.map { |r| r[parser]&.[](:time_per_iteration) }.compact
      return 0.5 if times.empty?

      avg_time = times.sum / times.length.to_f
      all_times = results.values.flat_map { |r| r.values.map { |v| v[:time_per_iteration] } }.compact
      max_time = all_times.max

      return 0.5 if max_time.nil? || max_time == 0

      # Invert and normalize (faster = higher score)
      1.0 - (avg_time / max_time)
    end

    def calculate_memory_score(parser, results)
      return 0.5 unless results

      # Average memory usage across all test sizes (inverted - lower memory = higher score)
      memories = results.values.map { |r| r[parser]&.[](:allocated_memory) }.compact
      return 0.5 if memories.empty?

      avg_memory = memories.sum / memories.length.to_f
      all_memories = results.values.flat_map { |r| r.values.map { |v| v[:allocated_memory] } }.compact
      max_memory = all_memories.max

      return 0.5 if max_memory.nil? || max_memory == 0

      # Invert and normalize (less memory = higher score)
      1.0 - (avg_memory / max_memory)
    end

    def generate_ruby_version_comparison_chart
      return create_empty_chart('Multi-version data not available') unless @results[:ruby_versions]

      ruby_versions = @results[:ruby_versions].keys.sort

      # Create a line chart showing performance trends across Ruby versions
      create_version_trend_chart(
        title: 'Performance trends across Ruby versions',
        subtitle: 'Average DOM parsing performance by Ruby version',
        ruby_versions: ruby_versions,
        data_extractor: ->(version_data) { extract_average_dom_performance(version_data) }
      )
    end

    def generate_multi_version_overview_chart
      return create_empty_chart('Multi-version data not available') unless @results[:ruby_versions]

      # Create a comprehensive overview showing all parsers across all Ruby versions
      create_multi_version_heatmap
    end

    def generate_multi_version_dom_chart
      return create_empty_chart('Multi-version data not available') unless @results[:ruby_versions]

      create_multi_version_category_chart('DOM parsing', :dom_parsing)
    end

    def generate_multi_version_sax_chart
      return create_empty_chart('Multi-version data not available') unless @results[:ruby_versions]

      create_multi_version_category_chart('SAX parsing', :sax_parsing)
    end

    def generate_multi_version_generation_chart
      return create_empty_chart('Multi-version data not available') unless @results[:ruby_versions]

      create_multi_version_category_chart('XML generation', :xml_generation)
    end

    def create_version_trend_chart(title:, subtitle:, ruby_versions:, data_extractor:)
      width = 800
      height = 600
      margin = { top: 80, right: 150, bottom: 100, left: 80 }
      chart_width = width - margin[:left] - margin[:right]
      chart_height = height - margin[:top] - margin[:bottom]

      # Extract data for all parsers across versions
      parser_data = {}
      ruby_versions.each do |version|
        version_data = @results[:ruby_versions][version]
        performance = data_extractor.call(version_data)

        performance.each do |parser, value|
          parser_data[parser] ||= []
          parser_data[parser] << { version: version, value: value }
        end
      end

      return create_empty_chart('No trend data available') if parser_data.empty?

      max_value = parser_data.values.flat_map { |data| data.map { |d| d[:value] } }.max || 1

      <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="#{width}" height="#{height}" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <style>
              .chart-title { font-family: Arial, sans-serif; font-size: 20px; font-weight: bold; text-anchor: middle; }
              .chart-subtitle { font-family: Arial, sans-serif; font-size: 14px; text-anchor: middle; fill: #666; }
              .axis-label { font-family: Arial, sans-serif; font-size: 12px; text-anchor: middle; }
              .tick-label { font-family: Arial, sans-serif; font-size: 10px; text-anchor: middle; }
              .legend-text { font-family: Arial, sans-serif; font-size: 11px; }
              .trend-line { stroke-width: 3; fill: none; }
              .trend-point { stroke-width: 2; fill: white; }
              .grid-line { stroke: #e0e0e0; stroke-width: 1; }
              .axis-line { stroke: #333; stroke-width: 2; }
            </style>
          </defs>

          <!-- Background -->
          <rect width="#{width}" height="#{height}" fill="white"/>

          <!-- Title -->
          <text x="#{width / 2}" y="30" class="chart-title">#{title}</text>
          <text x="#{width / 2}" y="50" class="chart-subtitle">#{subtitle}</text>

          <!-- Chart area -->
          <g transform="translate(#{margin[:left]}, #{margin[:top]})">
            <!-- Grid lines -->
            #{generate_trend_grid_lines(chart_width, chart_height, ruby_versions.length, max_value)}

            <!-- Trend lines -->
            #{generate_trend_lines(parser_data, ruby_versions, chart_width, chart_height, max_value)}

            <!-- Axes -->
            <line x1="0" y1="#{chart_height}" x2="#{chart_width}" y2="#{chart_height}" class="axis-line"/>
            <line x1="0" y1="0" x2="0" y2="#{chart_height}" class="axis-line"/>

            <!-- Axis labels -->
            #{generate_trend_x_labels(ruby_versions, chart_width, chart_height)}
            #{generate_trend_y_labels(chart_height, max_value)}

            <!-- Axis titles -->
            <text x="#{chart_width / 2}" y="#{chart_height + 50}" class="axis-label">Ruby version</text>
            <text x="-50" y="#{chart_height / 2}" class="axis-label" transform="rotate(-90, -50, #{chart_height / 2})">Time (ms)</text>
          </g>

          <!-- Legend -->
          #{generate_trend_legend(parser_data.keys, width, margin)}
        </svg>
      SVG
    end

    def create_multi_version_heatmap
      ruby_versions = @results[:ruby_versions].keys.sort
      parsers = extract_all_parsers_from_versions

      width = 800
      height = 600
      margin = { top: 80, right: 50, bottom: 100, left: 100 }

      <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="#{width}" height="#{height}" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <style>
              .chart-title { font-family: Arial, sans-serif; font-size: 20px; font-weight: bold; text-anchor: middle; }
              .axis-label { font-family: Arial, sans-serif; font-size: 12px; text-anchor: middle; }
              .heatmap-cell { stroke: white; stroke-width: 2; }
              .heatmap-text { font-family: Arial, sans-serif; font-size: 10px; text-anchor: middle; fill: white; }
            </style>
          </defs>

          <!-- Background -->
          <rect width="#{width}" height="#{height}" fill="white"/>

          <!-- Title -->
          <text x="#{width / 2}" y="30" class="chart-title">Multi-version performance heatmap</text>
          <text x="#{width / 2}" y="50" class="chart-subtitle">Relative performance across Ruby versions (darker = better)</text>

          <!-- Heatmap -->
          <g transform="translate(#{margin[:left]}, #{margin[:top]})">
            #{generate_heatmap_cells(ruby_versions, parsers, width - margin[:left] - margin[:right], height - margin[:top] - margin[:bottom])}
            #{generate_heatmap_labels(ruby_versions, parsers, width - margin[:left] - margin[:right], height - margin[:top] - margin[:bottom])}
          </g>
        </svg>
      SVG
    end

    def create_multi_version_category_chart(category_name, category_key)
      ruby_versions = @results[:ruby_versions].keys.sort

      # Aggregate data across versions for this category
      aggregated_data = {}
      ruby_versions.each do |version|
        version_data = @results[:ruby_versions][version]
        category_data = version_data[category_key]
        next unless category_data

        category_data.each do |size, parsers|
          aggregated_data[size] ||= {}
          parsers.each do |parser, results|
            next if results[:error]

            aggregated_data[size]["#{parser}_#{version}"] = results[:time_per_iteration]
          end
        end
      end

      create_bar_chart(
        title: "#{category_name} performance across Ruby versions",
        subtitle: 'Time per iteration by Ruby version (lower is better)',
        data: aggregated_data,
        y_label: 'Time (milliseconds)',
        value_formatter: ->(v) { "#{(v * 1000).round(2)}ms" }
      )
    end

    def extract_average_dom_performance(version_data)
      return {} unless version_data[:dom_parsing]

      averages = {}
      version_data[:dom_parsing].each do |size, parsers|
        parsers.each do |parser, results|
          next if results[:error]

          averages[parser] ||= []
          averages[parser] << results[:time_per_iteration]
        end
      end

      # Calculate averages
      averages.transform_values { |times| times.sum / times.length.to_f }
    end

    def extract_all_parsers_from_versions
      parsers = []
      @results[:ruby_versions].each_value do |version_data|
        version_data[:dom_parsing]&.each_value do |size_data|
          parsers.concat(size_data.keys)
        end
      end
      parsers.uniq
    end

    def generate_trend_grid_lines(chart_width, chart_height, num_x_ticks, max_value)
      lines = []

      # Horizontal grid lines
      (0..5).each do |i|
        y = chart_height - (i * chart_height / 5.0)
        lines << %(<line x1="0" y1="#{y}" x2="#{chart_width}" y2="#{y}" class="grid-line"/>)
      end

      # Vertical grid lines
      (0...num_x_ticks).each do |i|
        x = i * chart_width / (num_x_ticks - 1).to_f
        lines << %(<line x1="#{x}" y1="0" x2="#{x}" y2="#{chart_height}" class="grid-line"/>)
      end

      lines.join("\n")
    end

    def generate_trend_lines(parser_data, ruby_versions, chart_width, chart_height, max_value)
      lines = []

      parser_data.each do |parser, data|
        color = COLORS[parser.to_sym] || '#999999'
        points = []

        data.each do |point|
          version_index = ruby_versions.index(point[:version])
          next unless version_index

          x = version_index * chart_width / (ruby_versions.length - 1).to_f
          y = chart_height - (point[:value] / max_value * chart_height)
          points << "#{x},#{y}"
        end

        next if points.empty?

        lines << %(<polyline points="#{points.join(' ')}" stroke="#{color}" class="trend-line"/>)

        # Add points
        points.each do |point|
          x, y = point.split(',').map(&:to_f)
          lines << %(<circle cx="#{x}" cy="#{y}" r="4" stroke="#{color}" class="trend-point"/>)
        end
      end

      lines.join("\n")
    end

    def generate_trend_x_labels(ruby_versions, chart_width, chart_height)
      labels = []
      ruby_versions.each_with_index do |version, index|
        x = index * chart_width / (ruby_versions.length - 1).to_f
        labels << %(<text x="#{x}" y="#{chart_height + 20}" class="tick-label">Ruby #{version}</text>)
      end
      labels.join("\n")
    end

    def generate_trend_y_labels(chart_height, max_value)
      labels = []
      (0..5).each do |i|
        value = i * max_value / 5.0
        y = chart_height - (i * chart_height / 5.0)
        formatted_value = "#{(value * 1000).round(1)}ms"
        labels << %(<text x="-10" y="#{y + 4}" class="tick-label" text-anchor="end">#{formatted_value}</text>)
      end
      labels.join("\n")
    end

    def generate_trend_legend(parsers, width, margin)
      legend_x = width - margin[:right] - 120
      legend_y = margin[:top] + 20

      legend_items = []
      parsers.each_with_index do |parser, index|
        y = legend_y + index * 20
        color = COLORS[parser.to_sym] || '#999999'

        legend_items << <<~ITEM
          <line x1="#{legend_x}" y1="#{y}" x2="#{legend_x + 20}" y2="#{y}" stroke="#{color}" stroke-width="3"/>
          <text x="#{legend_x + 25}" y="#{y + 4}" class="legend-text">#{parser.capitalize}</text>
        ITEM
      end

      legend_items.join("\n")
    end

    def generate_heatmap_cells(ruby_versions, parsers, width, height)
      cell_width = width / ruby_versions.length.to_f
      cell_height = height / parsers.length.to_f

      cells = []
      ruby_versions.each_with_index do |version, v_index|
        parsers.each_with_index do |parser, p_index|
          x = v_index * cell_width
          y = p_index * cell_height

          # Calculate performance score for this parser/version combination
          score = calculate_heatmap_score(version, parser)
          color_intensity = (score * 255).to_i
          color = "rgb(#{255 - color_intensity}, #{255 - color_intensity}, 255)"

          cells << %(<rect x="#{x}" y="#{y}" width="#{cell_width}" height="#{cell_height}" fill="#{color}" class="heatmap-cell"/>)
        end
      end

      cells.join("\n")
    end

    def generate_heatmap_labels(ruby_versions, parsers, width, height)
      cell_width = width / ruby_versions.length.to_f
      cell_height = height / parsers.length.to_f

      labels = []

      # Version labels (top)
      ruby_versions.each_with_index do |version, index|
        x = index * cell_width + cell_width / 2
        labels << %(<text x="#{x}" y="-10" class="axis-label">Ruby #{version}</text>)
      end

      # Parser labels (left)
      parsers.each_with_index do |parser, index|
        y = index * cell_height + cell_height / 2
        labels << %(<text x="-10" y="#{y}" class="axis-label" text-anchor="end">#{parser.capitalize}</text>)
      end

      labels.join("\n")
    end

    def calculate_heatmap_score(version, parser)
      version_data = @results[:ruby_versions][version]
      return 0.5 unless version_data && version_data[:dom_parsing]

      # Calculate average performance for this parser in this version
      times = []
      version_data[:dom_parsing].each_value do |size_data|
        next unless size_data[parser] && !size_data[parser][:error]

        times << size_data[parser][:time_per_iteration]
      end

      return 0.5 if times.empty?

      avg_time = times.sum / times.length.to_f

      # Get all times across all versions for normalization
      all_times = []
      @results[:ruby_versions].each_value do |vd|
        next unless vd[:dom_parsing]

        vd[:dom_parsing].each_value do |sd|
          sd.each_value do |pd|
            next if pd[:error]

            all_times << pd[:time_per_iteration]
          end
        end
      end

      return 0.5 if all_times.empty?

      max_time = all_times.max
      min_time = all_times.min

      return 0.5 if max_time == min_time

      # Normalize (lower time = higher score)
      1.0 - (avg_time - min_time) / (max_time - min_time)
    end

    def create_empty_chart(message)
      <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="400" height="200" xmlns="http://www.w3.org/2000/svg">
          <rect width="400" height="200" fill="white" stroke="#ddd"/>
          <text x="200" y="100" text-anchor="middle" font-family="Arial" font-size="14" fill="#666">#{message}</text>
        </svg>
      SVG
    end
  end
end
