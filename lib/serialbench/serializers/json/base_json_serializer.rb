# frozen_string_literal: true

require_relative '../base_serializer'

module Serialbench
  module Serializers
    module Json
      class BaseJsonSerializer < BaseSerializer
        def self.format
          :json
        end

        # JSON-specific methods
        def parse_object(json_string)
          parse(json_string)
        end

        def generate_json(object, options = {})
          generate(object, options)
        end

        def capabilities
          super | Set.new(%i[pretty_print])
        end

        # JSON-specific features
        def features
          {
            pretty_print: supports?(:pretty_print),
            streaming: supports?(:sax) || supports?(:streaming),
            symbol_keys: supports?(:symbol_keys),
            custom_types: supports?(:custom_types)
          }
        end

        # Subclasses should override this to specify their library name
        def library_require_name
          raise NotImplementedError, 'Subclasses must implement #library_require_name'
        end

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
