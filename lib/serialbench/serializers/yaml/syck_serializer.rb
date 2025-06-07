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
            defined?(Syck) && Syck.respond_to?(:dump) && Syck.respond_to?(:load)
          rescue LoadError
            false
          end
        end

        def parse(yaml_string)
          return nil unless available?
          require 'syck'
          Syck.load(yaml_string)
        end

        def generate(object, options = {})
          return nil unless available?
          require 'syck'
          Syck.dump(object)
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
      end
    end
  end
end
