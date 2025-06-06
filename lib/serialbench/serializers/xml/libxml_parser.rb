# frozen_string_literal: true

require_relative 'base_parser'

module Serialbench
  module Parsers
    class LibxmlParser < BaseParser
      def parse_dom(xml_string)
        require 'libxml'
        LibXML::XML::Document.string(xml_string)
      end

      def parse_sax(xml_string, handler = nil)
        require 'libxml'
        handler ||= LibxmlSaxHandler.new
        parser = LibXML::XML::SaxParser.string(xml_string)
        parser.callbacks = handler
        parser.parse
        handler
      end

      def generate_xml(document, options = {})
        require 'libxml'
        document.to_s
      end

      def supports_streaming?
        true
      end

      # SAX handler for LibXML
      class LibxmlSaxHandler
        attr_reader :elements_processed, :text_nodes_processed

        def initialize
          @elements_processed = 0
          @text_nodes_processed = 0
          # Include LibXML callbacks if available
          return unless defined?(::LibXML)

          return if self.class.ancestors.include?(::LibXML::XML::SaxParser::Callbacks)

          self.class.send(:include,
                          ::LibXML::XML::SaxParser::Callbacks)
        end

        def on_start_document
          # Document processing started
        end

        def on_end_document
          # Document processing complete
        end

        def on_start_element(element, attributes)
          @elements_processed += 1
        end

        def on_characters(chars)
          @text_nodes_processed += 1 unless chars.strip.empty?
        end

        def on_end_element(element)
          # Element processing complete
        end

        def on_error(msg)
          # Handle parsing errors
        end
      end

      protected

      def library_require_name
        'libxml'
      end

      def detect_version
        require 'libxml'
        LibXML::XML::VERSION
      rescue LoadError
        'not available'
      end

      def supports_xpath?
        true
      end

      def supports_namespaces?
        true
      end

      def supports_validation?
        true
      end
    end
  end
end
