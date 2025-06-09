# frozen_string_literal: true

require 'liquid'
require 'fileutils'
require 'json'

module JsonFilter
  def jsonify(input)
    JSON.generate(input)
  end
end

module Serialbench
  # Renders HTML reports using Liquid templates
  class TemplateRenderer
    TEMPLATE_DIR = File.join(__dir__, 'templates')

  def initialize
    @liquid_env = Liquid::Environment.new
    @liquid_env.file_system = Liquid::LocalFileSystem.new(TEMPLATE_DIR)

    # Register custom filters
    Liquid::Template.register_filter(JsonFilter)
  end

    # Render a single benchmark report
    def render_single_benchmark(data, output_dir)
      template_data = prepare_single_benchmark_data(data)
      content_template = load_template('single_benchmark.liquid')
      content = content_template.render(template_data)

      base_template = load_template('base.liquid')
      html = base_template.render(template_data.merge('content' => content))

      write_report(html, output_dir, 'benchmark_report.html')
      copy_assets(output_dir)
    end

    # Render a multi-version comparison report
    def render_multi_version(data, output_dir)
      template_data = prepare_multi_version_data(data)
      content_template = load_template('multi_version.liquid')
      content = content_template.render(template_data)

      base_template = load_template('base.liquid')
      html = base_template.render(template_data.merge('content' => content))

      write_report(html, output_dir, 'index.html')
      copy_assets(output_dir)
    end

    # Render a format-based multi-version comparison report
    def render_format_based(data, output_dir)
      template_data = prepare_format_based_data(data)
      template = load_template('format_based.liquid')
      html = template.render(template_data)

      write_report(html, output_dir, 'index.html')
      copy_assets(output_dir)
    end

    # Render a platform matrix comparison report
    def render_platform_matrix(data, output_dir)
      template_data = prepare_platform_matrix_data(data)
      template = load_template('platform_matrix.liquid')
      html = template.render(template_data)

      write_report(html, output_dir, 'index.html')
    end

    # Render using a specific template name
    def render_template(template_name, data)
      template = load_template("#{template_name}.liquid")

      # Handle special template data preparation
      case template_name
      when 'format_based'
        template_data = prepare_format_based_data(data)
      else
        template_data = data
      end

      template.render(template_data)
    end

    private

    def load_template(template_name)
      template_path = File.join(TEMPLATE_DIR, template_name)
      template_content = File.read(template_path)

      # Ensure JsonFilter is registered for this template
      Liquid::Template.register_filter(JsonFilter)

      Liquid::Template.parse(template_content)
    end

    def prepare_single_benchmark_data(data)
      {
        'page_title' => 'Serialbench - Performance Report',
        'report_title' => 'Serialbench Performance Report',
        'report_subtitle' => 'Comprehensive serialization performance benchmarks',
        'metadata' => {
          'generated_at' => Time.now.strftime('%Y-%m-%d %H:%M:%S'),
          'ruby_version' => RUBY_VERSION,
          'platform' => RUBY_PLATFORM
        },
        'navigation' => build_single_navigation,
        'sections' => build_single_sections(data),
        'inline_javascript' => build_single_javascript(data)
      }
    end

    def prepare_multi_version_data(data)
      environments = extract_environments(data)
      ruby_versions = data.dig('metadata', 'ruby_versions') || []
      platforms = data.dig('metadata', 'platforms') || []

      {
        'page_title' => 'Serialbench - Multi-Version Comparison',
        'report_title' => 'Serialbench Multi-Version Comparison',
        'report_subtitle' => 'Performance comparison across Ruby versions and platforms',
        'metadata' => {
          'generated_at' => Time.now.strftime('%Y-%m-%d %H:%M:%S'),
          'ruby_versions' => ruby_versions,
          'platforms' => platforms
        },
        'navigation' => build_multi_navigation,
        'sections' => build_multi_sections(data, environments),
        'inline_javascript' => build_multi_javascript(data, environments)
      }
    end

    def prepare_format_based_data(data)
      # Handle both symbol and string keys
      metadata = data[:metadata] || data['metadata'] || {}

      # Check if we have embedded_data (from test script) or direct data
      if data[:embedded_data] || data['embedded_data']
        embedded_str = data[:embedded_data] || data['embedded_data']
        if embedded_str.is_a?(String)
          embedded_data = JSON.parse(embedded_str)
        else
          embedded_data = embedded_str
        end
        combined_results = embedded_data['combined_results'] || {}
        environments = embedded_data['environments'] || {}
        embedded_metadata = embedded_data['metadata'] || {}
      else
        # Direct data structure
        combined_results = data[:combined_results] || data['combined_results'] || {}
        environments = data[:environments] || data['environments'] || {}
        embedded_metadata = {}
      end

      # Extract ruby versions and platforms from metadata or environments
      ruby_versions = metadata[:ruby_versions] || metadata['ruby_versions'] ||
                     embedded_metadata['ruby_versions'] || []
      platforms = metadata[:platforms] || metadata['platforms'] ||
                 embedded_metadata['platforms'] || []

      if ruby_versions.empty? && !environments.empty?
        ruby_versions = environments.values.map { |env| env[:ruby_version] || env['ruby_version'] }.compact.uniq
      end

      if platforms.empty? && !environments.empty?
        platforms = environments.values.map { |env| env[:ruby_platform] || env['ruby_platform'] }.compact.uniq
      end

      # Build the format structure for the template
      formats = %w[xml json yaml toml].map.with_index do |format, index|
        {
          'name' => format,
          'active' => index == 0
        }
      end

      {
        'page_title' => data[:page_title] || data['page_title'] || 'Serialbench - Format Comparison',
        'report_title' => data[:report_title] || data['report_title'] || 'Serialbench Multi-Format Comparison',
        'report_subtitle' => data[:report_subtitle] || data['report_subtitle'] || 'Performance comparison across serialization formats and Ruby versions',
        'metadata' => {
          'generated_at' => metadata[:generated_at] || metadata['generated_at'] || Time.now.strftime('%Y-%m-%d %H:%M:%S'),
          'ruby_versions' => ruby_versions,
          'platforms' => platforms,
          'timestamp' => metadata[:timestamp] || metadata['timestamp']
        },
        'formats' => formats,
        # Pass the data directly to the template variables
        'combined_results' => combined_results,
        'environments' => environments
      }
    end


    def prepare_platform_matrix_data(data)
      {
        'metadata' => {
          'merged_at' => data.dig('metadata', 'merged_at') || Time.now.iso8601,
          'ruby_versions' => data.dig('metadata', 'ruby_versions') || [],
          'platforms' => data.dig('metadata', 'platforms') || []
        },
        'combined_results' => data['combined_results'] || {},
        'environments' => data['environments'] || {},
        'site' => {
          'formats' => %w[xml json yaml toml],
          'sizes' => %w[small medium large]
        }
      }
    end

    def build_single_navigation
      [
        { 'label' => 'Parsing Performance', 'section' => 'parsing', 'active' => true },
        { 'label' => 'Generation Performance', 'section' => 'generation', 'active' => false },
        { 'label' => 'Streaming Performance', 'section' => 'streaming', 'active' => false },
        { 'label' => 'Memory Usage', 'section' => 'memory', 'active' => false },
        { 'label' => 'Summary', 'section' => 'summary', 'active' => false }
      ]
    end

    def build_multi_navigation
      [
        { 'label' => 'Parsing Performance', 'section' => 'parsing', 'active' => true },
        { 'label' => 'Generation Performance', 'section' => 'generation', 'active' => false },
        { 'label' => 'Streaming Performance', 'section' => 'streaming', 'active' => false },
        { 'label' => 'Memory Usage', 'section' => 'memory', 'active' => false },
        { 'label' => 'Summary', 'section' => 'summary', 'active' => false },
        { 'label' => 'Environments', 'section' => 'environments', 'active' => false }
      ]
    end

    def build_single_sections(data)
      sections = []

      # Parsing section
      sections << {
        'id' => 'parsing',
        'title' => 'Parsing Performance',
        'type' => 'charts',
        'active' => true,
        'size_groups' => build_size_groups(data, 'parsing')
      }

      # Generation section
      sections << {
        'id' => 'generation',
        'title' => 'Generation Performance',
        'type' => 'charts',
        'active' => false,
        'size_groups' => build_size_groups(data, 'generation')
      }

      # Streaming section
      sections << {
        'id' => 'streaming',
        'title' => 'Streaming Performance',
        'type' => 'charts',
        'active' => false,
        'size_groups' => build_size_groups(data, 'streaming')
      }

      # Memory section
      sections << {
        'id' => 'memory',
        'title' => 'Memory Usage',
        'type' => 'charts',
        'active' => false,
        'size_groups' => build_memory_size_groups(data)
      }

      # Summary section
      sections << {
        'id' => 'summary',
        'title' => 'Performance Summary',
        'type' => 'summary',
        'active' => false,
        'cards' => build_summary_cards(data)
      }

      sections
    end

    def build_multi_sections(data, environments)
      sections = build_single_sections(data)

      # Add environments section
      sections << {
        'id' => 'environments',
        'title' => 'Test Environments',
        'type' => 'environments',
        'active' => false,
        'environments' => environments
      }

      sections
    end

    def build_size_groups(data, operation_type)
      size_groups = []

      %w[small medium large].each do |size|
        charts = []

        # Performance chart
        charts << {
          'id' => "#{operation_type}_#{size}_performance",
          'title' => "#{operation_type.capitalize} Performance - #{size.capitalize} Files"
        }

        size_groups << {
          'title' => "#{size.capitalize} Files",
          'charts' => charts
        }
      end

      size_groups
    end

    def build_memory_size_groups(data)
      size_groups = []

      %w[small medium large].each do |size|
        charts = []

        # Memory chart
        charts << {
          'id' => "memory_#{size}",
          'title' => "Memory Usage - #{size.capitalize} Files"
        }

        size_groups << {
          'title' => "#{size.capitalize} Files",
          'charts' => charts
        }
      end

      size_groups
    end

    def build_summary_cards(data)
      [
        {
          'title' => 'Fastest Parsers',
          'content_type' => 'list',
          'items' => ['Ox (XML)', 'Oj (JSON)', 'Psych (YAML)', 'Tomlib (TOML)']
        },
        {
          'title' => 'Most Memory Efficient',
          'content_type' => 'list',
          'items' => ['REXML (XML)', 'JSON (JSON)', 'Psych (YAML)', 'TOML-RB (TOML)']
        },
        {
          'title' => 'Best Overall',
          'content_type' => 'list',
          'items' => ['Nokogiri (XML)', 'Oj (JSON)', 'Psych (YAML)', 'Tomlib (TOML)']
        },
        {
          'title' => 'Recommendations',
          'content_type' => 'text',
          'content' => 'For production use, consider Nokogiri for XML, Oj for JSON, Psych for YAML, and Tomlib for TOML based on your performance requirements.'
        }
      ]
    end

    def build_single_javascript(data)
      js_code = []

      # Generate chart creation calls for each section
      %w[parsing generation streaming].each do |operation|
        %w[small medium large].each do |size|
          chart_data = extract_chart_data(data, operation, size)
          js_code << "createSinglePerformanceChart('#{operation}_#{size}_performance', '#{operation.capitalize} Performance - #{size.capitalize} Files', #{chart_data.to_json}, 'iterations_per_second');"
        end
      end

      # Memory charts
      %w[small medium large].each do |size|
        chart_data = extract_memory_data(data, size)
        js_code << "createSingleMemoryChart('memory_#{size}', 'Memory Usage - #{size.capitalize} Files', #{chart_data.to_json});"
      end

      # Wrap in DOMContentLoaded to ensure scripts are loaded
      "document.addEventListener('DOMContentLoaded', function() {\n#{js_code.join("\n")}\n});"
    end

    def build_multi_javascript(data, environments)
      js_code = []
      env_names = environments.map { |env| env[:name] }

      # Generate chart creation calls for each section
      %w[parsing generation streaming].each do |operation|
        %w[small medium large].each do |size|
          chart_data = extract_multi_chart_data(data, operation, size)
          js_code << "createPerformanceChart('#{operation}_#{size}_performance', '#{operation.capitalize} Performance - #{size.capitalize} Files', #{chart_data.to_json}, 'iterations_per_second', #{env_names.to_json});"
        end
      end

      # Memory charts
      %w[small medium large].each do |size|
        chart_data = extract_multi_memory_data(data, size)
        js_code << "createMemoryChart('memory_#{size}', 'Memory Usage - #{size.capitalize} Files', #{chart_data.to_json}, #{env_names.to_json});"
      end

      # Wrap in DOMContentLoaded to ensure scripts are loaded
      "document.addEventListener('DOMContentLoaded', function() {\n#{js_code.join("\n")}\n});"
    end

    def extract_environments(data)
      # Extract environment information from merged data
      environments = []

      if data.is_a?(Hash) && data['environments']
        data['environments'].each do |env_name, env_data|
          # Get the nested environment data
          env_info = env_data['environment'] || env_data

          environments << {
            'name' => env_name.gsub('_', ' ').gsub(/(\d+)/, 'Ruby \1').gsub('aarch64 linux', '(aarch64-linux)'),
            'ruby_version' => env_data['ruby_version'] || env_info['ruby_version'],
            'platform' => env_data['ruby_platform'] || env_info['ruby_platform'] || env_data['platform'],
            'architecture' => extract_architecture(env_data['ruby_platform'] || env_info['ruby_platform']),
            'cpu' => env_info['cpu'] || 'ARM64',
            'memory' => env_info['memory'] || 'N/A',
            'serializer_versions' => env_info['serializer_versions'] || {},
            'timestamp' => env_data['timestamp'] || env_info['timestamp']
          }
        end
      end

      environments
    end

    def extract_architecture(platform)
      return 'ARM64' if platform&.include?('aarch64')
      return 'x86_64' if platform&.include?('x86_64')
      platform || 'Unknown'
    end

    def build_format_structure(data, environments)
      formats = []

      %w[xml json yaml toml].each_with_index do |format, index|
        format_data = {
          'name' => format,
          'active' => index == 0,
          'operations' => []
        }

        # Performance operations
        %w[parsing generation streaming].each_with_index do |operation, op_index|
          operation_data = {
            'name' => operation,
            'title' => "#{operation.capitalize} Performance",
            'type' => 'performance',
            'active' => op_index == 0,
            'sizes' => []
          }

          %w[small medium large].each_with_index do |size, size_index|
            operation_data['sizes'] << {
              'name' => size,
              'active' => size_index == 0
            }
          end

          format_data['operations'] << operation_data
        end

        # Memory operation
        format_data['operations'] << {
          'name' => 'memory',
          'title' => 'Memory Usage',
          'type' => 'performance',
          'active' => false,
          'sizes' => %w[small medium large].map.with_index do |size, size_index|
            {
              'name' => size,
              'active' => size_index == 0
            }
          end
        }

        # Summary operation
        format_data['operations'] << {
          'name' => 'summary',
          'title' => 'Performance Summary',
          'type' => 'summary',
          'active' => false,
          'cards' => build_format_summary_cards(format)
        }

        # Environment operation
        format_data['operations'] << {
          'name' => 'environment',
          'title' => 'Test Environments',
          'type' => 'environment',
          'active' => false,
          'environments' => environments
        }

        formats << format_data
      end

      formats
    end

    def build_format_summary_cards(format)
      case format
      when 'xml'
        [
          {
            'title' => 'Fastest XML Parsers',
            'type' => 'list',
            'items' => ['Ox - Ultra-fast C extension', 'LibXML - Reliable and fast', 'Nokogiri - Feature-rich']
          },
          {
            'title' => 'Most Compatible',
            'type' => 'list',
            'items' => ['REXML - Pure Ruby, always available', 'Nokogiri - Wide feature support']
          },
          {
            'title' => 'Recommendations',
            'type' => 'text',
            'content' => 'Use Ox for maximum speed, Nokogiri for features, or REXML for compatibility.'
          }
        ]
      when 'json'
        [
          {
            'title' => 'Fastest JSON Parsers',
            'type' => 'list',
            'items' => ['Oj - Optimized JSON', 'RapidJSON - Fast C++ parser', 'Standard JSON - Built-in']
          },
          {
            'title' => 'Most Compatible',
            'type' => 'list',
            'items' => ['Standard JSON - Always available', 'Oj - Wide adoption']
          },
          {
            'title' => 'Recommendations',
            'type' => 'text',
            'content' => 'Use Oj for best performance, standard JSON for compatibility.'
          }
        ]
      when 'yaml'
        [
          {
            'title' => 'Fastest YAML Parsers',
            'type' => 'list',
            'items' => ['Psych - Default YAML parser', 'Syck - Legacy parser']
          },
          {
            'title' => 'Most Compatible',
            'type' => 'list',
            'items' => ['Psych - Modern standard', 'Syck - Legacy support']
          },
          {
            'title' => 'Recommendations',
            'type' => 'text',
            'content' => 'Use Psych for modern Ruby versions, Syck only for legacy compatibility.'
          }
        ]
      when 'toml'
        [
          {
            'title' => 'Fastest TOML Parsers',
            'type' => 'list',
            'items' => ['Tomlib - Fast C extension', 'TOML-RB - Pure Ruby']
          },
          {
            'title' => 'Most Compatible',
            'type' => 'list',
            'items' => ['TOML-RB - Pure Ruby implementation', 'Tomlib - Fast but requires compilation']
          },
          {
            'title' => 'Recommendations',
            'type' => 'text',
            'content' => 'Use Tomlib for speed, TOML-RB for pure Ruby environments.'
          }
        ]
      else
        []
      end
    end

    def extract_chart_data(data, operation, size)
      # Extract chart data for single benchmark
      chart_data = {}

      if data.is_a?(Hash) && data[operation] && data[operation][size]
        data[operation][size].each do |serializer, results|
          chart_data[serializer] = results
        end
      end

      chart_data
    end

    def extract_memory_data(data, size)
      # Extract memory data for single benchmark
      chart_data = {}

      if data.is_a?(Hash) && data['memory'] && data['memory'][size]
        data['memory'][size].each do |serializer, results|
          chart_data[serializer] = results
        end
      end

      chart_data
    end

    def extract_multi_chart_data(data, operation, size)
      # Extract chart data for multi-version comparison
      chart_data = {}

      if data.is_a?(Hash) && data['combined_results'] && data['combined_results'][operation] && data['combined_results'][operation][size]
        operation_data = data['combined_results'][operation][size]

        # Iterate through format types (xml, json, yaml, toml)
        operation_data.each do |format, serializers|
          serializers.each do |serializer, env_results|
            # Transform env_results to the format expected by charts
            serializer_data = {}
            env_results.each do |env_name, metrics|
              serializer_data[env_name] = metrics['iterations_per_second'] || 0
            end
            chart_data[serializer] = serializer_data
          end
        end
      end

      chart_data
    end

    def extract_multi_memory_data(data, size)
      # Extract memory data for multi-version comparison
      # For now, return empty data since memory data structure needs to be implemented
      {}
    end

    def write_report(html, output_dir, filename)
      FileUtils.mkdir_p(output_dir)
      File.write(File.join(output_dir, filename), html)
    end

    def copy_assets(output_dir)
      assets_source = File.join(TEMPLATE_DIR, 'assets')
      assets_dest = File.join(output_dir, 'assets')

      if Dir.exist?(assets_source)
        FileUtils.cp_r(assets_source, assets_dest)
      end
    end
  end
end
