# frozen_string_literal: true

require 'json-schema'
require 'yaml'

module Serialbench
  # Validates YAML files against YAML Schema definitions
  class YamlValidator
    SCHEMA_DIR = File.join(__dir__, '..', '..', 'data', 'schemas')

    class << self
      def validate(file_path, schema_name)
        unless File.exist?(file_path)
          raise ArgumentError, "File not found: #{file_path}"
        end

        data = YAML.load_file(file_path)
        schema_path = File.join(SCHEMA_DIR, "#{schema_name}.yml")

        unless File.exist?(schema_path)
          raise ArgumentError, "Schema not found: #{schema_path}"
        end

        schema = YAML.load_file(schema_path)

        # Validate without strict schema checking (allow additional properties)
        JSON::Validator.validate!(schema, data, strict: false)

        true
      rescue JSON::Schema::ValidationError => e
        puts "❌ Validation failed: #{e.message}"
        false
      end
    end
  end
end
