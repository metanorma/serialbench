# frozen_string_literal: true

require_relative '../base_serializer'

module Serialbench
  module Serializers
    module Json
      class BaseJsonSerializer < BaseSerializer
        def format
          :json
        end

        # JSON-specific methods
        def parse_object(json_string)
          parse(json_string)
        end

        def generate_json(object, options = {})
          generate(object, options)
        end

        # JSON-specific features
        def features
          {
            pretty_print: supports_pretty_print?,
            streaming: supports_streaming?,
            symbol_keys: supports_symbol_keys?,
            custom_types: supports_custom_types?
          }
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

        # Subclasses should override this to specify their library name
        def library_require_name
          raise NotImplementedError, 'Subclasses must implement #library_require_name'
        end

        public

        # Check if the JSON library is available
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
