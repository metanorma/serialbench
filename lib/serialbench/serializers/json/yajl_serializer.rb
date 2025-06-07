# frozen_string_literal: true

require_relative 'base_json_serializer'

module Serialbench
  module Serializers
    module Json
      class YajlSerializer < BaseJsonSerializer
        def name
          'yajl'
        end

        def parse(json_string)
          require 'yajl'
          Yajl::Parser.parse(json_string)
        end

        def generate(data, options = {})
          require 'yajl'
          if options[:pretty]
            Yajl::Encoder.encode(data, pretty: true, indent: '  ')
          else
            Yajl::Encoder.encode(data)
          end
        end

        def parse_streaming(json_string, &block)
          require 'yajl'

          parser = Yajl::Parser.new
          parser.on_parse_complete = block if block

          # Parse the JSON string
          result = parser.parse(json_string)

          # Return number of top-level objects processed
          case result
          when Array
            result.length
          when Hash
            1
          else
            1
          end
        end

        def supports_streaming?
          true
        end

        def version
          return 'unknown' unless available?

          require 'yajl'
          # YAJL doesn't have a VERSION constant, try to get gem version
          begin
            Gem.loaded_specs['yajl-ruby']&.version&.to_s || 'unknown'
          rescue StandardError
            'unknown'
          end
        end

        protected

        def library_require_name
          'yajl'
        end
      end
    end
  end
end
