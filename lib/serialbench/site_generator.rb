# frozen_string_literal: true

require 'fileutils'
require 'erb'
require 'json'
require 'liquid'
require 'yaml'

module Serialbench
  # Unified site generator for creating static HTML sites from benchmark results
  class SiteGenerator
    TEMPLATE_DIR = File.join(__dir__, 'templates')

    attr_reader :output_path, :result, :resultset

    def initialize(output_path:, result: nil, resultset: nil)
      @output_path = File.expand_path(output_path)
      @result = result if result
      @resultset = resultset if resultset
      setup_liquid_environment
    end

    def self.generate_for_result(result, output_path)
      generator = new(output_path: output_path, result: result)
      generator.generate_site
    end

    def self.generate_for_resultset(resultset, output_path)
      generator = new(output_path: output_path, resultset: resultset)
      generator.generate_site
    end

    def generate_site
      target_name = @result ? @result.environment_config.name : @resultset.name

      puts "🏗️  Generating HTML site for #{@result ? 'run' : 'resultset'}: #{target_name}"
      puts "Output: #{@output_path}"

      # Transform data for dashboard.js compatibility
      data = if @result
               transform_result_for_dashboard(@result)
             else
               transform_resultset_for_dashboard(@resultset)
             end

      prepare_output_directory
      render_site(
        {
          'data' => JSON.generate(data),
          'kind' => @result ? 'run' : 'resultset'
        },
        'format_based.liquid'
      )

      puts "✅ Site generated successfully at: #{@output_path}"
      @output_path
    end

    private

    def setup_liquid_environment
      @liquid_env = Liquid::Environment.new
      @liquid_env.file_system = Liquid::LocalFileSystem.new(TEMPLATE_DIR)
    end

    def prepare_output_directory
      if Dir.exist?(@output_path)
        puts 'Cleaning existing output directory...'
        FileUtils.rm_rf(Dir.glob(File.join(@output_path, '*')))
      else
        FileUtils.mkdir_p(@output_path)
      end
    end

    def render_site(template_data, template_name)
      # Load and render content template
      content_template = load_template(template_name)
      content = content_template.render(template_data)

      # Load and render base template
      base_template = load_template('base.liquid')
      html = base_template.render(template_data.merge('content' => content))

      # Write HTML file
      write_file(html, 'index.html')

      # Copy assets
      copy_assets
    end

    def load_template(template_name)
      template_path = File.join(TEMPLATE_DIR, template_name)
      template_content = File.read(template_path)
      Liquid::Template.parse(template_content)
    end

    def write_file(content, filename)
      FileUtils.mkdir_p(@output_path)
      File.write(File.join(@output_path, filename), content)
    end

    def copy_assets
      assets_source = File.join(TEMPLATE_DIR, 'assets')
      assets_dest = File.join(@output_path, 'assets')

      return unless Dir.exist?(assets_source)

      FileUtils.cp_r(assets_source, assets_dest)
    end

    # Transform a single Result into dashboard-compatible format
    # Dashboard expects: { combined_results: {...}, environments: {...}, metadata: {...} }
    def transform_result_for_dashboard(result)
      env_key = "env-#{result.platform.ruby_version}"

      # Build combined_results structure
      combined_results = build_combined_results(result, env_key)

      # Build environments structure
      environments = {
        env_key => {
          'ruby_version' => result.platform.ruby_version,
          'ruby_platform' => result.platform.ruby_platform || "#{result.platform.os}-#{result.platform.arch}",
          'os' => result.platform.os,
          'arch' => result.platform.arch,
          'source_file' => result.metadata.environment_config_path,
          'timestamp' => result.metadata.created_at
        }
      }

      {
        'combined_results' => combined_results,
        'environments' => environments,
        'metadata' => {
          'generated_at' => Time.now.iso8601
        }
      }
    end

    # Transform a ResultSet (collection of Results) into dashboard-compatible format
    # Combines all results into a single dashboard structure
    def transform_resultset_for_dashboard(resultset)
      combined_results = {}
      environments = {}

      resultset.results.each do |result|
        # Create unique env key for this result
        env_key = "#{result.platform.os}-#{result.platform.arch}-ruby-#{result.platform.ruby_version}"

        # Merge this result's data into combined_results
        result_combined = build_combined_results(result, env_key)
        merge_combined_results!(combined_results, result_combined)

        # Add environment info
        environments[env_key] = {
          'ruby_version' => result.platform.ruby_version,
          'ruby_platform' => result.platform.ruby_platform || "#{result.platform.os}-#{result.platform.arch}",
          'os' => result.platform.os,
          'arch' => result.platform.arch,
          'source_file' => result.metadata.environment_config_path,
          'timestamp' => result.metadata.created_at
        }
      end

      {
        'combined_results' => combined_results,
        'environments' => environments,
        'metadata' => {
          'resultset_name' => resultset.name,
          'resultset_description' => resultset.description,
          'total_runs' => resultset.results.size,
          'generated_at' => Time.now.iso8601
        }
      }
    end

    # Deep merge results from multiple runs
    def merge_combined_results!(target, source)
      source.each do |operation, sizes|
        target[operation] ||= {}
        sizes.each do |size, formats|
          target[operation][size] ||= {}
          formats.each do |format, serializers|
            target[operation][size][format] ||= {}
            serializers.each do |serializer, envs|
              target[operation][size][format][serializer] ||= {}
              target[operation][size][format][serializer].merge!(envs)
            end
          end
        end
      end
    end

    def build_combined_results(result, env_key)
      combined = {}

      %w[parsing generation streaming].each do |operation|
        combined[operation] = {}

        operation_results = result.benchmark_result.send(operation)
        next if operation_results.nil? || operation_results.empty?

        operation_results.each do |perf|
          size = perf.data_size
          format = perf.format
          serializer = perf.adapter

          combined[operation][size] ||= {}
          combined[operation][size][format] ||= {}
          combined[operation][size][format][serializer] ||= {}
          combined[operation][size][format][serializer][env_key] = {
            'iterations_per_second' => perf.iterations_per_second,
            'time_per_iteration' => perf.time_per_iteration
          }
        end
      end

      # Handle memory separately
      if result.benchmark_result.memory && !result.benchmark_result.memory.empty?
        combined['memory'] = {}

        result.benchmark_result.memory.each do |mem|
          size = mem.data_size
          format = mem.format
          serializer = mem.adapter

          combined['memory'][size] ||= {}
          combined['memory'][size][format] ||= {}
          combined['memory'][size][format][serializer] ||= {}
          combined['memory'][size][format][serializer][env_key] = {
            'allocated_memory' => mem.allocated_memory,
            'retained_memory' => mem.retained_memory
          }
        end
      end

      combined
    end
  end
end
