# frozen_string_literal: true

require_relative '../base_serializer'

module Serialbench
  module Serializers
    module Xml
      class BaseXmlSerializer < BaseSerializer
        def self.format
          :xml
        end

        # XML-specific methods
        def parse_dom(xml_string)
          parse(xml_string)
        end

        def parse_sax(xml_string, &block)
          stream_parse(xml_string, &block)
        end

        def generate_xml(document, options = {})
          generate(document, options)
        end

        # XML-specific features derive from the capability set
        def features
          {
            xpath: supports?(:xpath),
            namespaces: supports?(:namespaces),
            validation: supports?(:validation),
            streaming: supports?(:sax) || supports?(:streaming),
            stax: supports?(:stax)
          }
        end

        def supports_generation?
          true
        end

        def supports_xpath?
          false
        end

        def supports_namespaces?
          true
        end

        def supports_validation?
          false
        end

        # Check if the XML library is available
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
