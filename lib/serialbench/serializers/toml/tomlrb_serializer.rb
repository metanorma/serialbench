# frozen_string_literal: true

require_relative 'base_toml_serializer'

module Serialbench
  module Serializers
    module Toml
      class TomlrbSerializer < BaseTomlSerializer
        def available?
          require_library('tomlrb')
        end

        def name
          'tomlrb'
        end

        def version
          require 'tomlrb'
          # tomlrb doesn't expose a VERSION constant, so we'll use gem version
          Gem.loaded_specs['tomlrb']&.version&.to_s || 'unknown'
        rescue LoadError, NameError
          'unknown'
        end

        def parse(toml_string)
          require 'tomlrb'
          Tomlrb.parse(toml_string)
        end

        def generate(object, options = {})
          raise NotImplementedError, 'tomlrb gem does not support TOML generation/dumping'
        end

        def supports_generation?
          false
        end

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
