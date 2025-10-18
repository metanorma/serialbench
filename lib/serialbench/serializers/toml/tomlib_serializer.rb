# frozen_string_literal: true

require_relative 'base_toml_serializer'

module Serialbench
  module Serializers
    module Toml
      class TomlibSerializer < BaseTomlSerializer
        def name
          'tomlib'
        end

        def parse(toml_string)
          require 'tomlib'
          Tomlib.load(toml_string)
        end

        def generate(data)
          require 'tomlib'
          Tomlib.dump(data)
        end

        def parse_streaming(toml_string, &block)
          # TOML doesn't typically support streaming parsing
          # Parse the entire document and yield it
          result = parse(toml_string)
          block&.call(result)
          1 # Return 1 document processed
        end

        def supports_streaming?
          false # TOML is typically parsed as a whole document
        end

        def version
          return 'unknown' unless available?

          require 'tomlib'
          Tomlib::VERSION
        end

        def library_require_name
          'tomlib'
        end
      end
    end
  end
end
