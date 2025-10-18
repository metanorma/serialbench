# frozen_string_literal: true

require_relative 'base_yaml_serializer'

module Serialbench
  module Serializers
    module Yaml
      # Psych YAML serializer - Ruby's built-in YAML parser
      class PsychSerializer < BaseYamlSerializer
        def available?
          require_library('psych')
        end

        def name
          'psych'
        end

        def version
          require 'psych'
          Psych::VERSION
        end

        def parse(yaml_string)
          require 'psych'
          # Handle Ruby version compatibility for permitted_classes parameter
          if RUBY_VERSION >= '3.1.0'
            Psych.load(yaml_string, permitted_classes: [Date, Time, Symbol])
          else
            # For older Ruby versions, use the old API
            Psych.load(yaml_string)
          end
        end

        def generate(object, _options = {})
          require 'psych'
          Psych.dump(object)
        end

        def features
          %w[parsing generation built-in]
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
