# frozen_string_literal: true

require_relative 'base_yaml_serializer'

module Serialbench
  module Serializers
    module Yaml
      class SyckSerializer < BaseYamlSerializer
        def name
          'syck'
        end

        def version
          require 'syck'
          # Try to get version from gem specification
          spec = Gem.loaded_specs['syck']
          return spec.version.to_s if spec

          # Fallback to a default version if no gem spec found
          '1.0.0'
        rescue StandardError
          'N/A'
        end

        def available?
          require 'syck'
          # Verify that Syck module and methods are actually available
          return false unless defined?(Syck) && Syck.respond_to?(:dump) && Syck.respond_to?(:load)

          # Check for known problematic configurations
          if problematic_environment?
            warn_about_segfault_issue
            return false
          end

          true
        rescue LoadError
          false
        end

        def parse(yaml_string)
          return nil unless available?

          begin
            require 'syck'
            Syck.load(yaml_string)
          rescue StandardError => e
            if e.message.include?('Segmentation fault') || e.is_a?(SystemExit)
              handle_segfault_error
              return nil
            end
            raise e
          end
        end

        def generate(object, options = {})
          return nil unless available?

          begin
            require 'syck'
            Syck.dump(object)
          rescue StandardError => e
            if e.message.include?('Segmentation fault') || e.is_a?(SystemExit)
              handle_segfault_error
              return nil
            end
            raise e
          end
        end

        def supports_streaming?
          false
        end

        def features
          %w[parsing generation legacy]
        end

        def description
          'Legacy YAML parser (Ruby < 1.9.3)'
        end

        def problematic_environment?
          # Ruby 3.1+ has issues with Syck
          (Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.1.0')) &&
            (Gem::Version.new(version) >= Gem::Version.new('1.4.0'))
        end

        def warn_about_segfault_issue
          puts "⚠️  WARNING: The Syck YAML serializer is known to cause segmentation faults with Ruby #{RUBY_VERSION}"
          puts '   This is a known issue with the syck gem on newer Ruby versions systems.'
          puts '   Skipping Syck benchmarks to prevent crashes. See README for more details.'
        end

        def handle_segfault_error
          puts '❌ ERROR: Syck YAML serializer encountered a segmentation fault'
          puts "   This is a known issue on Ruby #{RUBY_VERSION}. Skipping remaining Syck tests."
        end
      end
    end
  end
end
