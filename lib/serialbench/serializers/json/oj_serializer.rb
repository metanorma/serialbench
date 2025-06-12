# frozen_string_literal: true

require_relative 'base_json_serializer'

module Serialbench
  module Serializers
    module Json
      class OjSerializer < BaseJsonSerializer
        def available?
          require_library('oj')
        end

        def name
          'oj'
        end

        def version
          require 'oj'
          Oj::VERSION
        rescue LoadError, NameError
          'unknown'
        end

        def parse(json_string)
          require 'oj'
          Oj.load(json_string)
        end

        def generate(object, options = {})
          require 'oj'
          if options[:pretty]
            Oj.dump(object, indent: 2)
          else
            Oj.dump(object)
          end
        end

        def stream_parse(json_string, &block)
          require 'oj'
          # Oj supports streaming through saj (Simple API for JSON)
          handler = StreamHandler.new(&block)
          Oj.saj_parse(handler, json_string)
          handler.result
        rescue LoadError, NoMethodError
          # Fallback to regular parsing if streaming not available
          super
        end

        def supports_streaming?
          require 'oj'
          Oj.respond_to?(:saj_parse)
        rescue LoadError
          false
        end

        def supports_pretty_print?
          true
        end

        def supports_symbol_keys?
          true
        end

        def supports_custom_types?
          true
        end
      end

      # Stream handler for Oj SAJ parsing
      class StreamHandler
        attr_reader :result

        def initialize(&block)
          @block = block
          @result = nil
        end

        def hash_start(key)
          @block&.call(:hash_start, key)
        end

        def hash_end(key)
          @block&.call(:hash_end, key)
        end

        def array_start(key)
          @block&.call(:array_start, key)
        end

        def array_end(key)
          @block&.call(:array_end, key)
        end

        def add_value(value, key)
          @block&.call(:value, { key: key, value: value })
        end
      end
    end
  end
end
