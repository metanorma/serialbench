# frozen_string_literal: true

require_relative '../base_serializer'

module Serialbench
  module Serializers
    module Toml
      class BaseTomlSerializer < BaseSerializer
        def self.format
          :toml
        end

        # TOML-specific methods
        def parse_config(toml_string)
          parse(toml_string)
        end

        def generate_toml(object, options = {})
          generate(object, options)
        end

        def capabilities
          super | Set.new(%i[arrays_of_tables inline_tables multiline_strings])
        end

        # TOML-specific features
        def features
          {
            comments: supports?(:comments),
            arrays_of_tables: supports?(:arrays_of_tables),
            inline_tables: supports?(:inline_tables),
            multiline_strings: supports?(:multiline_strings)
          }
        end

        # Subclasses should override this to specify their library name
        def library_require_name
          raise NotImplementedError, 'Subclasses must implement #library_require_name'
        end

        # Check if the TOML library is available
        def available?
          return @available if defined?(@available)

          @available = begin
            require library_require_name
            true
          rescue LoadError
            false
          end
        end
      end
    end
  end
end
