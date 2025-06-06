# frozen_string_literal: true

module Serialbench
  module Parsers
    class BaseParser
      attr_reader :name, :version

      def initialize
        @name = self.class.name.split('::').last.gsub('Parser', '').downcase
        @version = detect_version
      end

      # Parse XML string into document object
      def parse_dom(xml_string)
        raise NotImplementedError, 'Subclasses must implement parse_dom'
      end

      # Parse XML with SAX-style streaming
      def parse_sax(xml_string, handler = nil)
        raise NotImplementedError, 'Subclasses must implement parse_sax'
      end

      # Generate XML string from document object
      def generate_xml(document, options = {})
        raise NotImplementedError, 'Subclasses must implement generate_xml'
      end

      # Check if library is available
      def available?
        require library_require_name
        true
      rescue LoadError
        false
      end

      # Get library features
      def features
        {
          xpath: supports_xpath?,
          namespaces: supports_namespaces?,
          validation: supports_validation?,
          streaming: supports_streaming?
        }
      end

      def supports_streaming?
        false
      end

      protected

      def detect_version
        'unknown'
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
    end
  end
end
