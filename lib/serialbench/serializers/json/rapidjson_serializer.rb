# frozen_string_literal: true

require_relative 'base_json_serializer'

module Serialbench
  module Serializers
    module Json
      # RapidJSON serializer - Ruby bindings for RapidJSON C++ library
      class RapidjsonSerializer < BaseJsonSerializer
        def available?
          require_library('rapidjson')
        end

        def name
          'rapidjson'
        end

        def version
          require 'rapidjson'
          RapidJSON::VERSION
        rescue StandardError
          'unknown'
        end

        def parse(json_string)
          require 'rapidjson'
          RapidJSON.parse(json_string)
        end

        def generate(object, _options = {})
          require 'rapidjson'
          RapidJSON.dump(object)
        end

        def features
          %w[parsing generation high-performance c-extension]
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
