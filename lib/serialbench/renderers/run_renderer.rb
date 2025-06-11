# frozen_string_literal: true

require_relative '../template_renderer'

module Serialbench
  module Renderers
    # Renders HTML reports for individual benchmark runs
    class RunRenderer < TemplateRenderer
      def render(result, output_dir)
        template_data = prepare_run_data(result)
        content_template = load_template('single_benchmark.liquid')
        content = content_template.render(template_data)

        base_template = load_template('base.liquid')
        html = base_template.render(template_data.merge('content' => content))

        write_report(html, output_dir, 'index.html')
        copy_assets(output_dir)
      end

      private

      def prepare_run_data(result)
        {
          'page_title' => "Serialbench - #{result.name}",
          'report_title' => "Serialbench Result: #{result.name}",
          'report_subtitle' => "Performance results for #{result.environment.name}",
          'metadata' => build_run_metadata(result),
          'navigation' => build_run_navigation,
          'sections' => build_run_sections(result.results),
          'inline_javascript' => build_run_javascript(result.results)
        }
      end

      def build_run_metadata(result)
        {
          'generated_at' => format_timestamp(Time.now),
          'ruby_version' => result.environment.ruby_version,
          'platform' => result.environment.platform,
          'started_at' => format_timestamp(result.execution.started_at),
          'completed_at' => format_timestamp(result.execution.completed_at),
          'duration' => result.execution.duration_seconds,
          'status' => result.execution.status
        }
      end

      def build_run_navigation
        [
          { label: 'Parsing Performance', id: 'parsing' },
          { label: 'Generation Performance', id: 'generation' },
          { label: 'Memory Usage', id: 'memory' },
          { label: 'Summary', id: 'summary' }
        ]
      end

      def build_run_sections(results)
        sections = []

        # Parsing section
        if results.parsing && !results.parsing.empty?
          sections << {
            'id' => 'parsing',
            'title' => 'Parsing Performance',
            'type' => 'charts',
            'active' => true,
            'size_groups' => build_size_groups(results.parsing, 'parsing')
          }
        end

        # Generation section
        if results.generation && !results.generation.empty?
          sections << {
            'id' => 'generation',
            'title' => 'Generation Performance',
            'type' => 'charts',
            'active' => sections.empty?,
            'size_groups' => build_size_groups(results.generation, 'generation')
          }
        end

        # Memory section
        if results.memory && !results.memory.empty?
          sections << {
            'id' => 'memory',
            'title' => 'Memory Usage',
            'type' => 'charts',
            'active' => sections.empty?,
            'size_groups' => build_memory_size_groups(results.memory)
          }
        end

        # Summary section
        sections << {
          'id' => 'summary',
          'title' => 'Performance Summary',
          'type' => 'summary',
          'active' => sections.empty?,
          'cards' => build_summary_cards(results)
        }

        sections
      end

      def build_size_groups(operation_results, operation_type)
        size_groups = []

        operation_results.each do |size, formats|
          charts = []

          formats.each do |format, serializers|
            charts << {
              'id' => "#{operation_type}_#{size}_#{format}",
              'title' => "#{operation_type.capitalize} Performance - #{size.capitalize} #{format.upcase} Files",
              'data' => serializers
            }
          end

          size_groups << {
            'title' => "#{size.capitalize} Files",
            'charts' => charts
          }
        end

        size_groups
      end

      def build_memory_size_groups(memory_results)
        size_groups = []

        memory_results.each do |size, formats|
          charts = []

          formats.each do |format, serializers|
            charts << {
              'id' => "memory_#{size}_#{format}",
              'title' => "Memory Usage - #{size.capitalize} #{format.upcase} Files",
              'data' => serializers
            }
          end

          size_groups << {
            'title' => "#{size.capitalize} Files",
            'charts' => charts
          }
        end

        size_groups
      end

      def build_summary_cards(results)
        cards = []

        # Find fastest parsers
        if results.parsing
          fastest_parsers = find_fastest_serializers(results.parsing)
          cards << {
            'title' => 'Fastest Parsers',
            'content_type' => 'list',
            'items' => fastest_parsers
          }
        end

        # Find most memory efficient
        if results.memory
          efficient_serializers = find_most_efficient_serializers(results.memory)
          cards << {
            'title' => 'Most Memory Efficient',
            'content_type' => 'list',
            'items' => efficient_serializers
          }
        end

        # Add recommendations
        cards << {
          'title' => 'Recommendations',
          'content_type' => 'text',
          'content' => build_recommendations(results)
        }

        cards
      end

      def find_fastest_serializers(parsing_results)
        fastest = []

        parsing_results.each do |size, formats|
          formats.each do |format, serializers|
            best = serializers.max_by { |name, data| data['iterations_per_second'] || 0 }
            fastest << "#{best[0]} (#{format.upcase})" if best
          end
        end

        fastest.uniq.take(5)
      end

      def find_most_efficient_serializers(memory_results)
        efficient = []

        memory_results.each do |size, formats|
          formats.each do |format, serializers|
            best = serializers.min_by { |name, data| data['total_allocated_mb'] || Float::INFINITY }
            efficient << "#{best[0]} (#{format.upcase})" if best
          end
        end

        efficient.uniq.take(5)
      end

      def build_recommendations(results)
        recommendations = []

        if results.parsing
          recommendations << 'For parsing performance, consider the fastest serializers identified above.'
        end

        recommendations << 'For memory efficiency, use the serializers with lowest memory allocation.' if results.memory

        recommendations << 'Choose serializers based on your specific performance requirements and compatibility needs.'

        recommendations.join(' ')
      end

      def build_run_javascript(results)
        js_code = []

        # Generate chart creation calls for parsing
        if results.parsing
          results.parsing.each do |size, formats|
            formats.each do |format, serializers|
              chart_data = serializers.to_json
              js_code << "createRunPerformanceChart('parsing_#{size}_#{format}', 'Parsing Performance - #{size.capitalize} #{format.upcase}', #{chart_data}, 'iterations_per_second');"
            end
          end
        end

        # Generate chart creation calls for generation
        if results.generation
          results.generation.each do |size, formats|
            formats.each do |format, serializers|
              chart_data = serializers.to_json
              js_code << "createRunPerformanceChart('generation_#{size}_#{format}', 'Generation Performance - #{size.capitalize} #{format.upcase}', #{chart_data}, 'iterations_per_second');"
            end
          end
        end

        # Generate chart creation calls for memory
        if results.memory
          results.memory.each do |size, formats|
            formats.each do |format, serializers|
              chart_data = serializers.to_json
              js_code << "createRunMemoryChart('memory_#{size}_#{format}', 'Memory Usage - #{size.capitalize} #{format.upcase}', #{chart_data});"
            end
          end
        end

        # Wrap in DOMContentLoaded
        "document.addEventListener('DOMContentLoaded', function() {\n#{js_code.join("\n")}\n});"
      end
    end
  end
end
