# frozen_string_literal: true

require_relative '../base_serializer'

module Serialbench
  module Serializers
    module Yaml
      # Base class for YAML serializers
      class BaseYamlSerializer < BaseSerializer
        def self.format
          :yaml
        end

        def supports_streaming?
          false # Most YAML parsers don't support streaming
        end

        def features
          features = %w[parsing generation]
          features << 'streaming' if supports_streaming?
          features
        end

        # Default YAML generation options
        def default_generation_options
          {}
        end

        # Parse YAML string into Ruby object
        def parse(yaml_string)
          raise NotImplementedError, 'Subclasses must implement parse method'
        end

        # Generate YAML string from Ruby object
        def generate(object, options = {})
          raise NotImplementedError, 'Subclasses must implement generate method'
        end

        # Stream parse YAML (if supported)
        def stream_parse(yaml_string, &block)
          raise NotImplementedError, 'Streaming not supported by this YAML serializer'
        end

        def supports_generation?
          true
        end

        private

        def require_library(library_name)
          require library_name
          true
        rescue LoadError
          false
        end
      end
    end
  end
end
