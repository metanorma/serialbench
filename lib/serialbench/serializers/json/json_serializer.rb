# frozen_string_literal: true

require_relative 'base_json_serializer'

module Serialbench
  module Serializers
    module Json
      class JsonSerializer < BaseJsonSerializer
        def available?
          require_library('json')
        end

        def name
          'json'
        end

        def version
          require 'json'
          JSON::VERSION
        rescue LoadError, NameError
          'built-in'
        end

        def parse(json_string)
          require 'json'
          JSON.parse(json_string)
        end

        def generate(object, options = {})
          require 'json'
          if options[:pretty]
            JSON.pretty_generate(object)
          else
            JSON.generate(object)
          end
        end

        def supports_streaming?
          false
        end

        protected

        def supports_pretty_print?
          true
        end

        def supports_symbol_keys?
          false
        end

        def supports_custom_types?
          false
        end
      end
    end
  end
end
