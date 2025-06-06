# frozen_string_literal: true

require_relative 'base_parser'

module Serialbench
  module Parsers
    class NokogiriParser < BaseParser
      def parse_dom(xml_string)
        require 'nokogiri'
        Nokogiri::XML(xml_string)
      end

      def parse_sax(xml_string, handler = nil)
        require 'nokogiri'
        handler ||= NokogiriSaxHandler.new
        parser = Nokogiri::XML::SAX::Parser.new(handler)
        parser.parse(xml_string)
        handler
      end

      def generate_xml(document, options = {})
        require 'nokogiri'
        indent = options.fetch(:indent, 0)
        if indent > 0
          document.to_xml(indent: indent)
        else
          document.to_xml
        end
      end

      def supports_streaming?
        true
      end

      # SAX handler for Nokogiri
      class NokogiriSaxHandler < (defined?(::Nokogiri) ? ::Nokogiri::XML::SAX::Document : Object)
        attr_reader :elements_processed, :text_nodes_processed

        def initialize
          @elements_processed = 0
          @text_nodes_processed = 0
        end

        def start_document
          # Document processing started
        end

        def end_document
          # Document processing complete
        end

        def start_element(name, attrs = [])
          @elements_processed += 1
        end

        def start_element_namespace(name, attrs = [], prefix = nil, uri = nil, ns = [])
          @elements_processed += 1
        end

        def characters(string)
          @text_nodes_processed += 1 unless string.strip.empty?
        end

        def end_element(name)
          # Element processing complete
        end

        def end_element_namespace(name, prefix = nil, uri = nil)
          # Element processing complete
        end

        def error(message)
          # Handle parsing errors
        end

        def warning(message)
          # Handle parsing warnings
        end

        def xmldecl(version, encoding, standalone)
          # Handle XML declaration
        end
      end

      protected

      def library_require_name
        'nokogiri'
      end

      def detect_version
        require 'nokogiri'
        Nokogiri::VERSION
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
