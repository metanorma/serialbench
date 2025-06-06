# frozen_string_literal: true

require_relative 'base_toml_serializer'

module Serialbench
  module Serializers
    module Toml
      class TomlRbSerializer < BaseTomlSerializer
        def available?
          require_library('toml-rb')
        end

        def name
          'toml-rb'
        end

        def version
          require 'toml-rb'
          # toml-rb doesn't expose a VERSION constant, so we'll use gem version
          Gem.loaded_specs['toml-rb']&.version&.to_s || 'unknown'
        rescue LoadError, NameError
          'unknown'
        end

        def parse(toml_string)
          require 'toml-rb'
          TomlRB.parse(toml_string)
        end

        def generate(object, options = {})
          require 'toml-rb'
          TomlRB.dump(object)
        end

        protected

        def supports_comments?
          false
        end

        def supports_arrays_of_tables?
          true
        end

        def supports_inline_tables?
          true
        end

        def supports_multiline_strings?
          true
        end
      end
    end
  end
end
