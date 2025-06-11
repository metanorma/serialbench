# frozen_string_literal: true

require 'fileutils'
require_relative 'run_result'
require_relative 'run_set_result'
require_relative '../template_renderer'

module Serialbench
  module Models
    class Report
      attr_reader :source, :output_path, :template_type

      def initialize(source, output_path: '_site', template_type: nil)
        @source = source
        @output_path = output_path
        @template_type = template_type || detect_template_type
      end

      def self.generate(source, output_path = '_site', template_type: nil)
        report = new(source, output_path: output_path, template_type: template_type)
        report.generate
        report
      end

      def generate
        FileUtils.mkdir_p(@output_path)

        case @source
        when RunResult
          generate_single_run_report
        when RunSetResult
          generate_run_set_report
        when String
          # Path to run or run set
          if File.exist?(File.join(@source, 'metadata.yaml')) &&
             YAML.load_file(File.join(@source, 'metadata.yaml'))['name']
            # It's a run set
            run_set = RunSetResult.load(@source)
            @source = run_set
            generate_run_set_report
          else
            # It's a single run
            run = RunResult.load(@source)
            @source = run
            generate_single_run_report
          end
        else
          raise ArgumentError, "Unsupported source type: #{@source.class}"
        end

        self
      end

      def url
        File.join(@output_path, 'index.html')
      end

      def files_created
        Dir.glob(File.join(@output_path, '**', '*')).select { |f| File.file?(f) }
      end

      private

      def detect_template_type
        case @source
        when RunResult
          'single_benchmark'
        when RunSetResult
          if @source.run_count == 1
            'single_benchmark'
          else
            'format_based'
          end
        else
          'format_based'
        end
      end

      def generate_single_run_report
        renderer = Serialbench::TemplateRenderer.new

        # Prepare data for template
        data = @source.benchmark_result.to_hash

        # Generate HTML report
        html_content = renderer.render(@template_type, data)
        File.write(File.join(@output_path, 'index.html'), html_content)

        # Copy assets
        copy_assets

        # Save data files
        @source.benchmark_result.to_json_file(File.join(@output_path, 'results.json'))
        @source.benchmark_result.to_yaml_file(File.join(@output_path, 'results.yaml'))

        # Save metadata
        File.write(File.join(@output_path, 'metadata.json'), @source.metadata.to_json)
        File.write(File.join(@output_path, 'platform.json'), JSON.pretty_generate(@source.platform.to_hash))
      end

      def generate_run_set_report
        renderer = Serialbench::TemplateRenderer.new

        # Prepare data for template
        data = @source.merged_result.to_hash

        # Generate HTML report
        html_content = renderer.render(@template_type, data)
        File.write(File.join(@output_path, 'index.html'), html_content)

        # Copy assets
        copy_assets

        # Save merged data files
        @source.merged_result.to_json_file(File.join(@output_path, 'merged_results.json'))
        @source.merged_result.to_yaml_file(File.join(@output_path, 'merged_results.yaml'))

        # Save run set metadata
        File.write(File.join(@output_path, 'runset_metadata.json'), @source.metadata.to_json)

        # Save individual run summaries
        run_summaries = @source.runs.map do |run|
          {
            'platform_string' => run.platform_string,
            'ruby_version' => run.ruby_version,
            'created_at' => run.created_at,
            'tags' => run.tags,
            'path' => run.path
          }
        end
        File.write(File.join(@output_path, 'runs_summary.json'), JSON.pretty_generate(run_summaries))
      end

      def copy_assets
        # Copy CSS and JS assets from templates
        assets_source = File.join(File.dirname(__FILE__), '..', 'templates', 'assets')
        assets_dest = File.join(@output_path, 'assets')

        if Dir.exist?(assets_source)
          FileUtils.cp_r(assets_source, @output_path)
        end

        # Create a basic CSS file if assets don't exist
        unless Dir.exist?(assets_dest)
          FileUtils.mkdir_p(File.join(assets_dest, 'css'))
          File.write(File.join(assets_dest, 'css', 'styles.css'), basic_css)
        end
      end

      def basic_css
        <<~CSS
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
          }

          h1, h2, h3 {
            color: #2c3e50;
          }

          .benchmark-section {
            margin: 30px 0;
            padding: 20px;
            border: 1px solid #ddd;
            border-radius: 8px;
          }

          .performance-table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
          }

          .performance-table th,
          .performance-table td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
          }

          .performance-table th {
            background-color: #f8f9fa;
            font-weight: 600;
          }

          .performance-table tr:hover {
            background-color: #f5f5f5;
          }

          .chart-container {
            margin: 20px 0;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 8px;
          }

          .metadata {
            background: #e9ecef;
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
          }

          .tag {
            display: inline-block;
            background: #007bff;
            color: white;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 0.8em;
            margin: 2px;
          }
        CSS
      end
    end
  end
end
