# frozen_string_literal: true

require 'set'
require 'ostruct'
require_relative '../template_renderer'

module Serialbench
  module Renderers
    # Renders HTML reports for runset comparisons
    class RunsetRenderer < TemplateRenderer
      def render(result_set, output_dir)
        # Always use format_based template since it's the only one we have
        render_format_based(result_set, output_dir)
      end


      def render_format_based(result_set, output_dir)
        template_data = prepare_format_based_data(result_set)
        content_template = load_template('format_based.liquid')
        html = content_template.render(template_data)

        write_report(html, output_dir, 'index.html')
        copy_assets(output_dir)
      end

      private

      def prepare_runset_data(result_set)
        {
          'page_title' => "Serialbench - #{result_set.name}",
          'report_title' => "Serialbench Runset: #{result_set.name}",
          'report_subtitle' => "Performance comparison across #{result_set.result_count} runs",
          'metadata' => build_runset_metadata(result_set),
          'navigation' => build_runset_navigation,
          'sections' => build_runset_sections(result_set),
          'inline_javascript' => build_runset_javascript(result_set)
        }
      end

      def build_runset_metadata(result_set)
        {
          'generated_at' => format_timestamp(Time.now),
          'total_runs' => result_set.result_count,
          'environments' => extract_environments(result_set),
          'formats' => extract_formats(result_set),
          'created_at' => format_timestamp(result_set.created_at)
        }
      end

      def build_runset_navigation
        [
          { label: 'Parsing Comparison', id: 'parsing' },
          { label: 'Generation Comparison', id: 'generation' },
          { label: 'Memory Comparison', id: 'memory' },
          { label: 'Environments', id: 'environments' },
          { label: 'Summary', id: 'summary' }
        ]
      end

      def build_runset_sections(result_set)
        sections = []
        combined_results = combine_results(result_set)

        # Parsing comparison section
        if combined_results[:parsing] && !combined_results[:parsing].empty?
          sections << {
            'id' => 'parsing',
            'title' => 'Parsing Performance Comparison',
            'type' => 'comparison_charts',
            'active' => true,
            'size_groups' => build_comparison_size_groups(combined_results[:parsing], 'parsing')
          }
        end

        # Generation comparison section
        if combined_results[:generation] && !combined_results[:generation].empty?
          sections << {
            'id' => 'generation',
            'title' => 'Generation Performance Comparison',
            'type' => 'comparison_charts',
            'active' => sections.empty?,
            'size_groups' => build_comparison_size_groups(combined_results[:generation], 'generation')
          }
        end

        # Memory comparison section
        if combined_results[:memory] && !combined_results[:memory].empty?
          sections << {
            'id' => 'memory',
            'title' => 'Memory Usage Comparison',
            'type' => 'comparison_charts',
            'active' => sections.empty?,
            'size_groups' => build_memory_comparison_size_groups(combined_results[:memory])
          }
        end

        # Environments section
        sections << {
          'id' => 'environments',
          'title' => 'Test Environments',
          'type' => 'environments',
          'active' => sections.empty?,
          'environments' => build_environment_details(result_set)
        }

        # Summary section
        sections << {
          'id' => 'summary',
          'title' => 'Comparison Summary',
          'type' => 'summary',
          'active' => sections.empty?,
          'cards' => build_runset_summary_cards(combined_results, result_set)
        }

        sections
      end

      def combine_results(result_set)
        combined = { parsing: {}, generation: {}, memory: {} }

        result_set.result_paths.each do |run_path|
          result = load_result(run_path)
          next unless result

          # Create environment key in the format expected by the JavaScript
          env_key = "ruby-#{result.environment['ruby_version']}-#{result.environment['platform']}"

          # Combine parsing results
          if result.parsing_results
            result.parsing_results.each do |size, formats|
              combined[:parsing][size] ||= {}
              formats.each do |format, serializers|
                combined[:parsing][size][format] ||= {}
                serializers.each do |serializer, metrics|
                  combined[:parsing][size][format][serializer] ||= {}
                  combined[:parsing][size][format][serializer][env_key] = {
                    'iterations_per_second' => metrics['iterations_per_second'],
                    'allocated_memory' => 0 # Memory data not available in current structure
                  }
                end
              end
            end
          end

          # Combine generation results
          if result.generation_results
            result.generation_results.each do |size, formats|
              combined[:generation][size] ||= {}
              formats.each do |format, serializers|
                combined[:generation][size][format] ||= {}
                serializers.each do |serializer, metrics|
                  combined[:generation][size][format][serializer] ||= {}
                  combined[:generation][size][format][serializer][env_key] = {
                    'iterations_per_second' => metrics['iterations_per_second'],
                    'allocated_memory' => 0 # Memory data not available in current structure
                  }
                end
              end
            end
          end

          # Combine streaming results
          if result.streaming_results
            result.streaming_results.each do |size, formats|
              combined[:streaming] ||= {}
              combined[:streaming][size] ||= {}
              formats.each do |format, serializers|
                combined[:streaming][size][format] ||= {}
                serializers.each do |serializer, metrics|
                  combined[:streaming][size][format][serializer] ||= {}
                  combined[:streaming][size][format][serializer][env_key] = {
                    'iterations_per_second' => metrics['iterations_per_second'],
                    'allocated_memory' => 0 # Memory data not available in current structure
                  }
                end
              end
            end
          end

          # Memory results (empty for now since we don't have memory data)
          # combined[:memory] remains empty
        end

        combined
      end

      def build_comparison_size_groups(operation_results, operation_type)
        size_groups = []

        operation_results.each do |size, formats|
          charts = []

          formats.each do |format, serializers|
            charts << {
              'id' => "#{operation_type}_#{size}_#{format}",
              'title' => "#{operation_type.capitalize} Performance - #{size.capitalize} #{format.upcase} Files",
              'data' => serializers,
              'type' => 'comparison'
            }
          end

          size_groups << {
            'title' => "#{size.capitalize} Files",
            'charts' => charts
          }
        end

        size_groups
      end

      def build_memory_comparison_size_groups(memory_results)
        size_groups = []

        memory_results.each do |size, formats|
          charts = []

          formats.each do |format, serializers|
            charts << {
              'id' => "memory_#{size}_#{format}",
              'title' => "Memory Usage - #{size.capitalize} #{format.upcase} Files",
              'data' => serializers,
              'type' => 'memory_comparison'
            }
          end

          size_groups << {
            'title' => "#{size.capitalize} Files",
            'charts' => charts
          }
        end

        size_groups
      end

      def build_environment_details(result_set)
        environments = []

        result_set.result_paths.each do |run_path|
          result = load_result(run_path)
          next unless result

          environments << {
            'name' => result.environment['name'],
            'ruby_version' => result.environment['ruby_version'],
            'platform' => result.environment['platform'],
            'type' => result.environment['type'],
            'run_name' => extract_run_name(run_path),
            'started_at' => format_timestamp(result.started_at),
            'duration' => result.duration_seconds,
            'status' => result.status
          }
        end

        environments
      end

      def build_runset_summary_cards(combined_results, result_set)
        cards = []

        # Overall fastest across all runs
        if combined_results[:parsing] && !combined_results[:parsing].empty?
          fastest_overall = find_fastest_across_runs(combined_results[:parsing])
          cards << {
            'title' => 'Fastest Parsers Overall',
            'content_type' => 'list',
            'items' => fastest_overall
          }
        end

        # Most consistent performers
        if combined_results[:parsing] && !combined_results[:parsing].empty?
          consistent_performers = find_consistent_performers(combined_results[:parsing])
          cards << {
            'title' => 'Most Consistent Performers',
            'content_type' => 'list',
            'items' => consistent_performers
          }
        end

        # Environment comparison
        cards << {
          'title' => 'Environment Comparison',
          'content_type' => 'text',
          'content' => build_environment_comparison(result_set)
        }

        # Recommendations
        cards << {
          'title' => 'Recommendations',
          'content_type' => 'text',
          'content' => build_runset_recommendations(combined_results)
        }

        cards
      end

      def find_fastest_across_runs(parsing_results)
        fastest = []

        parsing_results.each do |size, formats|
          formats.each do |format, serializers|
            serializers.each do |serializer, runs|
              avg_performance = runs.values.map { |data| data['iterations_per_second'] || 0 }.sum / runs.size.to_f
              fastest << { name: "#{serializer} (#{format.upcase})", performance: avg_performance }
            end
          end
        end

        fastest.sort_by { |item| -item[:performance] }.take(5).map { |item| item[:name] }
      end

      def find_consistent_performers(parsing_results)
        consistent = []

        parsing_results.each do |size, formats|
          formats.each do |format, serializers|
            serializers.each do |serializer, runs|
              performances = runs.values.map { |data| data['iterations_per_second'] || 0 }
              next if performances.empty?

              avg = performances.sum / performances.size.to_f
              variance = performances.map { |p| (p - avg)**2 }.sum / performances.size.to_f
              coefficient_of_variation = Math.sqrt(variance) / avg

              consistent << { name: "#{serializer} (#{format.upcase})", consistency: coefficient_of_variation }
            end
          end
        end

        consistent.sort_by { |item| item[:consistency] }.take(5).map { |item| item[:name] }
      end

      def build_environment_comparison(result_set)
        env_count = result_set.result_count
        "Comparison across #{env_count} different environments shows performance variations due to Ruby versions, platforms, and system configurations."
      end

      def build_runset_recommendations(combined_results)
        recommendations = []

        recommendations << 'Choose serializers that perform consistently well across different environments.'
        recommendations << 'Consider the trade-offs between parsing speed and memory usage for your specific use case.'
        recommendations << 'Test with your actual data sizes and formats to validate these benchmark results.'

        recommendations.join(' ')
      end

      def build_runset_javascript(result_set)
        js_code = []
        combined_results = combine_results(result_set)
        run_names = extract_run_names(result_set)

        # Generate comparison charts for parsing
        if combined_results[:parsing]
          combined_results[:parsing].each do |size, formats|
            formats.each do |format, serializers|
              chart_data = serializers.to_json
              js_code << "createRunsetComparisonChart('parsing_#{size}_#{format}', 'Parsing Performance - #{size.capitalize} #{format.upcase}', #{chart_data}, 'iterations_per_second', #{run_names.to_json});"
            end
          end
        end

        # Generate comparison charts for generation
        if combined_results[:generation]
          combined_results[:generation].each do |size, formats|
            formats.each do |format, serializers|
              chart_data = serializers.to_json
              js_code << "createRunsetComparisonChart('generation_#{size}_#{format}', 'Generation Performance - #{size.capitalize} #{format.upcase}', #{chart_data}, 'iterations_per_second', #{run_names.to_json});"
            end
          end
        end

        # Generate comparison charts for memory
        if combined_results[:memory]
          combined_results[:memory].each do |size, formats|
            formats.each do |format, serializers|
              chart_data = serializers.to_json
              js_code << "createRunsetMemoryChart('memory_#{size}_#{format}', 'Memory Usage - #{size.capitalize} #{format.upcase}', #{chart_data}, #{run_names.to_json});"
            end
          end
        end

        # Wrap in DOMContentLoaded
        "document.addEventListener('DOMContentLoaded', function() {\n#{js_code.join("\n")}\n});"
      end

      def determine_template(result_set)
        # Check if runset has template configuration
        if result_set.respond_to?(:metadata) && result_set.metadata
          site_config = result_set.metadata['site_config'] || result_set.metadata[:site_config]
          if site_config
            template = site_config['template'] || site_config[:template]
            return template if template
          end
        end

        # Default to comparison template
        'comparison'
      end

      def prepare_format_based_data(result_set)
        combined_results = combine_results(result_set)
        environments = build_environment_info(result_set)

        {
          'page_title' => "SerialBench - Format Performance Dashboard",
          'combined_results' => combined_results,
          'environments' => environments,
          'metadata' => {
            'generated_at' => format_timestamp(Time.now),
            'ruby_versions' => extract_ruby_versions(result_set),
            'platforms' => extract_platforms(result_set),
            'timestamp' => format_timestamp(Time.now)
          }
        }
      end

      def build_environment_info(result_set)
        environments = {}

        result_set.result_paths.each do |run_path|
          result = load_result(run_path)
          next unless result

          # Use the same key format as in the combined_results data
          env_key = "ruby-#{result.environment['ruby_version']}-#{result.environment['platform']}"

          environments[env_key] = {
            'ruby_version' => result.environment['ruby_version'],
            'ruby_platform' => result.environment['platform'],
            'source_file' => run_path,
            'timestamp' => format_timestamp(result.started_at),
            'environment' => {
              'serializer_versions' => extract_serializer_versions(result)
            }
          }
        end

        environments
      end

      def extract_serializer_versions(result)
        versions = {}

        # Extract from parsing results if available
        if result.parsing_results
          result.parsing_results.each do |size, formats|
            formats.each do |format, serializers|
              serializers.each_key do |serializer|
                versions[serializer] = "unknown" # Version info not available in current structure
              end
            end
          end
        end

        versions
      end

      def extract_ruby_versions(result_set)
        versions = []
        result_set.result_paths.each do |run_path|
          result = load_result(run_path)
          versions << result.environment['ruby_version'] if result
        end
        versions.uniq.sort
      end

      def extract_platforms(result_set)
        platforms = []
        result_set.result_paths.each do |run_path|
          result = load_result(run_path)
          platforms << result.environment['platform'] if result
        end
        platforms.uniq
      end

      # Helper methods
      def load_result(run_path)
        # Try the expected result.yml first
        result_file = File.join(run_path, 'result.yml')
        if File.exist?(result_file)
          return Serialbench::Models::Result.load_from_file(result_file)
        end

        # Try the actual structure: data/results.yaml
        data_file = File.join(run_path, 'data', 'results.yaml')
        if File.exist?(data_file)
          raw_data = YAML.load_file(data_file)
          return convert_raw_result_to_model(raw_data, run_path)
        end

        # Try JSON version
        data_file_json = File.join(run_path, 'data', 'results.json')
        if File.exist?(data_file_json)
          raw_data = JSON.parse(File.read(data_file_json))
          return convert_raw_result_to_model(raw_data, run_path)
        end

        nil
      rescue StandardError => e
        puts "Warning: Failed to load result from #{run_path}: #{e.message}"
        nil
      end

      def convert_raw_result_to_model(raw_data, run_path)
        # Create a simple object that responds to the methods we need
        result = OpenStruct.new

        # Set basic properties
        result.name = File.basename(run_path)
        result.started_at = raw_data['timestamp'] || Time.now.iso8601
        result.status = 'success'
        result.duration_seconds = 0

        # Set environment info
        result.environment = {
          'name' => result.name,
          'type' => 'asdf',
          'ruby_version' => raw_data.dig('environment', 'ruby_version') || 'unknown',
          'platform' => raw_data.dig('environment', 'ruby_platform') || 'unknown'
        }

        # Set results directly from raw data
        result.parsing_results = raw_data['parsing'] || {}
        result.generation_results = raw_data['generation'] || {}
        result.streaming_results = raw_data['streaming'] || {}
        result.memory_results = {}

        # Set formats and data sizes
        result.formats = extract_formats_from_raw(raw_data)
        result.data_sizes = extract_data_sizes_from_raw(raw_data)

        # Set serializer versions
        result.serializer_versions = raw_data.dig('environment', 'serializer_versions') || {}

        result
      end

      def extract_formats_from_raw(raw_data)
        formats = Set.new
        ['parsing', 'generation', 'streaming'].each do |operation|
          next unless raw_data[operation]

          raw_data[operation].each do |size, size_data|
            size_data.each_key { |format| formats << format }
          end
        end
        formats.to_a
      end

      def extract_data_sizes_from_raw(raw_data)
        sizes = Set.new
        ['parsing', 'generation', 'streaming'].each do |operation|
          next unless raw_data[operation]

          raw_data[operation].each_key { |size| sizes << size }
        end
        sizes.to_a
      end

      def extract_run_name(run_path)
        File.basename(run_path)
      end

      def extract_run_names(result_set)
        result_set.result_paths.map { |run_path| extract_run_name(run_path) }
      end

      def extract_environments(result_set)
        environments = []
        result_set.result_paths.each do |run_path|
          result = load_result(run_path)
          environments << result.environment['name'] if result
        end
        environments.uniq
      end

      def extract_formats(result_set)
        formats = Set.new
        result_set.result_paths.each do |run_path|
          result = load_result(run_path)
          next unless result

          result.formats.each { |format| formats << format }
        end
        formats.to_a
      end
    end
  end
end
