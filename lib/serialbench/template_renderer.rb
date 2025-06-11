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
  # Base class for rendering HTML reports using Liquid templates
  class TemplateRenderer
    TEMPLATE_DIR = File.join(__dir__, 'templates')

    def initialize
      @liquid_env = Liquid::Environment.new
      @liquid_env.file_system = Liquid::LocalFileSystem.new(TEMPLATE_DIR)

      # Register custom filters
      Liquid::Template.register_filter(JsonFilter)
    end

    protected

    def load_template(template_name)
      template_path = File.join(TEMPLATE_DIR, template_name)
      template_content = File.read(template_path)

      # Ensure JsonFilter is registered for this template
      Liquid::Template.register_filter(JsonFilter)

      Liquid::Template.parse(template_content)
    end

    def write_report(html, output_dir, filename)
      FileUtils.mkdir_p(output_dir)
      File.write(File.join(output_dir, filename), html)
    end

    def copy_assets(output_dir)
      assets_source = File.join(TEMPLATE_DIR, 'assets')
      assets_dest = File.join(output_dir, 'assets')

      return unless Dir.exist?(assets_source)

      FileUtils.cp_r(assets_source, assets_dest)
    end

    def build_navigation(sections)
      sections.map.with_index do |section, index|
        {
          'label' => section[:label],
          'section' => section[:id],
          'active' => index == 0
        }
      end
    end

    def format_timestamp(timestamp)
      return Time.now.strftime('%Y-%m-%d %H:%M:%S') unless timestamp

      if timestamp.is_a?(String)
        Time.parse(timestamp).strftime('%Y-%m-%d %H:%M:%S')
      else
        timestamp.strftime('%Y-%m-%d %H:%M:%S')
      end
    rescue StandardError
      Time.now.strftime('%Y-%m-%d %H:%M:%S')
    end
  end
end
