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
          return 'N/A' unless available?

          begin
            require 'syck'
            # Try to get version from gem specification
            spec = Gem.loaded_specs['syck']
            return spec.version.to_s if spec

            # Fallback to a default version if no gem spec found
            '1.0.0'
          rescue
            'N/A'
          end
        end

        def available?
          begin
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
        end

        def parse(yaml_string)
          return nil unless available?

          begin
            require 'syck'
            Syck.load(yaml_string)
          rescue => e
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
          rescue => e
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

        private

        def problematic_environment?
          # Known issue: Syck segfaults on ARM64 with Ruby 3.1+
          arm64_architecture? && ruby_version_problematic?
        end

        def arm64_architecture?
          RUBY_PLATFORM.include?('arm64') || RUBY_PLATFORM.include?('aarch64')
        end

        def ruby_version_problematic?
          # Ruby 3.1+ has issues with Syck on ARM64
          version_parts = RUBY_VERSION.split('.').map(&:to_i)
          version_parts[0] > 3 || (version_parts[0] == 3 && version_parts[1] >= 1)
        end

        def warn_about_segfault_issue
          puts "⚠️  WARNING: Syck YAML serializer is known to cause segmentation faults on ARM64 architecture with Ruby #{RUBY_VERSION}"
          puts "   This is a known issue with the syck gem on newer Ruby versions and ARM64 systems."
          puts "   Skipping Syck benchmarks to prevent crashes. See README for more details."
        end

        def handle_segfault_error
          puts "❌ ERROR: Syck YAML serializer encountered a segmentation fault"
          puts "   This is a known issue on ARM64 with Ruby #{RUBY_VERSION}. Skipping remaining Syck tests."
        end
      end
    end
  end
end
