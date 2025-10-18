# frozen_string_literal: true

require 'yaml'
require 'ostruct'
require_relative 'schema_validator'

module Serialbench
  # Manages configuration loading and validation for Serialbench
  class ConfigManager
    class ConfigurationError < StandardError; end

    SCHEMA_PATH = File.join(__dir__, '../../docs/serialbench_config_schema.yaml')

    # Load and validate configuration from file
    def self.load_and_validate(config_path)
      new.load_and_validate(config_path)
    end

    def initialize
      @validator = SchemaValidator.new
    end

    # Load configuration file and validate against schema
    def load_and_validate(config_path)
      raise ConfigurationError, "Configuration file not found: #{config_path}" unless File.exist?(config_path)

      begin
        config_data = YAML.load_file(config_path)
      rescue Psych::SyntaxError => e
        raise ConfigurationError, "Invalid YAML syntax in #{config_path}: #{e.message}"
      rescue StandardError => e
        raise ConfigurationError, "Error reading configuration file #{config_path}: #{e.message}"
      end

      validate_config(config_data, config_path)
      normalize_config(config_data)
    end

    private

    # Validate configuration against schema
    def validate_config(config_data, _config_path)
      # For now, perform basic validation since we don't have a specific config schema validator
      validate_basic_config(config_data)
    end

    # Load the configuration schema
    def load_schema
      raise ConfigurationError, "Configuration schema not found: #{SCHEMA_PATH}" unless File.exist?(SCHEMA_PATH)

      begin
        YAML.load_file(SCHEMA_PATH)
      rescue StandardError => e
        raise ConfigurationError, "Error loading configuration schema: #{e.message}"
      end
    end

    # Normalize and convert configuration to structured object
    def normalize_config(config_data)
      config = OpenStruct.new(config_data)

      # Apply defaults
      config.output_dir ||= 'benchmark-results'
      config.benchmark_config ||= 'config/full.yml'
      config.auto_install = true if config.auto_install.nil?

      # Validate runtime-specific requirements
      case config.runtime
      when 'docker'
        validate_docker_config(config)
      when 'asdf'
        validate_asdf_config(config)
      else
        raise ConfigurationError, "Unknown runtime: #{config.runtime}"
      end

      config
    end

    # Validate Docker-specific configuration
    def validate_docker_config(config)
      raise ConfigurationError, "Docker runtime requires 'image_variants' to be specified" unless config.image_variants && !config.image_variants.empty?

      invalid_variants = config.image_variants - %w[slim alpine]
      return if invalid_variants.empty?

      raise ConfigurationError, "Invalid image variants: #{invalid_variants.join(', ')}. Valid variants: slim, alpine"
    end

    # Validate ASDF-specific configuration
    def validate_asdf_config(config)
      # Check if ASDF is available
      raise ConfigurationError, 'ASDF is not installed or not in PATH. Please install ASDF to use asdf runtime.' unless command_available?('asdf')

      # Validate Ruby version format for ASDF (should include patch version)
      config.ruby_versions.each do |version|
        raise ConfigurationError, "ASDF runtime requires full version numbers (e.g., '3.2.8'), got: #{version}" unless version.match?(/^\d+\.\d+\.\d+$/)
      end
    end

    # Basic configuration validation
    def validate_basic_config(config_data)
      # Check required fields
      required_fields = %w[runtime ruby_versions output_dir benchmark_config]
      required_fields.each do |field|
        raise ConfigurationError, "Missing required field: #{field}" unless config_data.key?(field)
      end

      # Validate runtime
      valid_runtimes = %w[docker asdf]
      unless valid_runtimes.include?(config_data['runtime'])
        raise ConfigurationError,
              "Invalid runtime: #{config_data['runtime']}. Valid runtimes: #{valid_runtimes.join(', ')}"
      end

      # Validate ruby_versions is an array
      raise ConfigurationError, 'ruby_versions must be an array' unless config_data['ruby_versions'].is_a?(Array)

      return unless config_data['ruby_versions'].empty?

      raise ConfigurationError, 'ruby_versions cannot be empty'
    end

    # Check if a command is available in PATH
    def command_available?(command)
      system("which #{command} > /dev/null 2>&1")
    end
  end
end
