# frozen_string_literal: true

require 'yaml'
require 'time'

module Serialbench
  module Models
    # Environment configuration model
    class Environment
      attr_reader :name, :type, :created_at, :description, :config

      VALID_TYPES = %w[docker asdf local].freeze

      def initialize(config_hash)
        @config = config_hash.dup
        @name = config_hash['name']
        @type = config_hash['type']
        @created_at = Time.parse(config_hash['created_at']) if config_hash['created_at']
        @description = config_hash['description']

        validate!
      end

      def self.load_from_file(file_path)
        config = YAML.load_file(file_path)
        new(config)
      rescue StandardError => e
        raise "Failed to load environment from #{file_path}: #{e.message}"
      end

      def self.create(name, type, options = {})
        config = {
          'name' => name,
          'type' => type,
          'created_at' => Time.now.iso8601,
          'description' => options[:description]
        }.compact

        case type
        when 'docker'
          config.merge!(docker_defaults(options))
        when 'asdf'
          config.merge!(asdf_defaults(options))
        when 'local'
          config.merge!(local_defaults(options))
        end

        new(config)
      end

      def save_to_file(file_path)
        File.write(file_path, @config.to_yaml)
      end

      def docker?
        @type == 'docker'
      end

      def asdf?
        @type == 'asdf'
      end

      def local?
        @type == 'local'
      end

      def ruby_versions
        @config['ruby_versions'] || []
      end

      def ruby_versions=(versions)
        @config['ruby_versions'] = versions
      end

      # Docker-specific methods
      def image_variants
        return [] unless docker?

        @config['image_variants'] || []
      end

      def build_args
        return {} unless docker?

        @config['build_args'] || {}
      end

      def run_args
        return {} unless docker?

        @config['run_args'] || {}
      end

      # ASDF-specific methods
      def auto_install?
        return false unless asdf?

        @config['auto_install'] != false
      end

      def global_gems
        return [] unless asdf?

        @config['global_gems'] || []
      end

      # Local-specific methods
      def ruby_path
        return nil unless local?

        @config['ruby_path']
      end

      def bundle_path
        return nil unless local?

        @config['bundle_path']
      end

      def env_vars
        return {} unless local?

        @config['env_vars'] || {}
      end

      def to_h
        @config.dup
      end

      def to_yaml
        @config.to_yaml
      end

      def ==(other)
        other.is_a?(Environment) && @config == other.config
      end

      def hash
        @config.hash
      end

      private

      def validate!
        raise ArgumentError, 'Environment name is required' if @name.nil? || @name.strip.empty?
        raise ArgumentError, 'Environment type is required' if @type.nil? || @type.strip.empty?
        raise ArgumentError, "Invalid environment type: #{@type}" unless VALID_TYPES.include?(@type)
        raise ArgumentError, 'Created timestamp is required' unless @created_at

        case @type
        when 'docker'
          validate_docker!
        when 'asdf'
          validate_asdf!
        when 'local'
          validate_local!
        end
      end

      def validate_docker!
        raise ArgumentError, 'Docker environments must specify at least one Ruby version' if ruby_versions.empty?

        ruby_versions.each do |version|
          raise ArgumentError, "Invalid Ruby version format: #{version}" unless version.match?(/^\d+\.\d+(\.\d+)?$/)
        end

        return unless image_variants.any? { |variant| !%w[slim alpine bullseye].include?(variant) }

        raise ArgumentError, 'Invalid Docker image variant'
      end

      def validate_asdf!
        raise ArgumentError, 'ASDF environments must specify at least one Ruby version' if ruby_versions.empty?

        ruby_versions.each do |version|
          unless version.match?(/^\d+\.\d+\.\d+$/)
            raise ArgumentError, "Invalid Ruby version format for ASDF: #{version} (must include patch version)"
          end
        end
      end

      def validate_local!
        # Local environments are more flexible, just validate paths if provided
        raise ArgumentError, 'Ruby path must be a string' if ruby_path && !ruby_path.is_a?(String)

        raise ArgumentError, 'Bundle path must be a string' if bundle_path && !bundle_path.is_a?(String)

        return unless env_vars && !env_vars.is_a?(Hash)

        raise ArgumentError, 'Environment variables must be a hash'
      end

      def self.docker_defaults(options)
        {
          'ruby_versions' => options[:ruby_versions] || ['3.2', '3.3'],
          'image_variants' => options[:image_variants] || %w[slim alpine],
          'build_args' => options[:build_args] || {},
          'run_args' => options[:run_args] || {}
        }
      end

      def self.asdf_defaults(options)
        {
          'ruby_versions' => options[:ruby_versions] || ['3.2.8', '3.3.8'],
          'auto_install' => options[:auto_install] != false,
          'global_gems' => options[:global_gems] || []
        }
      end

      def self.local_defaults(options)
        {
          'ruby_path' => options[:ruby_path],
          'bundle_path' => options[:bundle_path],
          'env_vars' => options[:env_vars] || {}
        }
      end
    end
  end
end
