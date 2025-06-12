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
      data = @result ? @result.to_json : @resultset.to_json

      puts "🏗️  Generating HTML site for #{@result ? 'run' : 'resultset'}: #{target_name}"
      puts "Output: #{@output_path}"

      prepare_output_directory
      render_site(
        {
          'data' => data,
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
  end
end
