# frozen_string_literal: true

require_relative '../base_serializer'

module Serialbench
  module Serializers
    module Toml
      class BaseTomlSerializer < BaseSerializer
        def format
          :toml
        end

        # TOML-specific methods
        def parse_config(toml_string)
          parse(toml_string)
        end

        def generate_toml(object, options = {})
          generate(object, options)
        end

        # TOML-specific features
        def features
          {
            comments: supports_comments?,
            arrays_of_tables: supports_arrays_of_tables?,
            inline_tables: supports_inline_tables?,
            multiline_strings: supports_multiline_strings?
          }
        end

        def supports_streaming?
          # TOML is typically not streamed due to its structure
          false
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

        # Subclasses should override this to specify their library name
        def library_require_name
          raise NotImplementedError, 'Subclasses must implement #library_require_name'
        end

        public

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
