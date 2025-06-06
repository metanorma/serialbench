# frozen_string_literal: true

require_relative 'base_parser'

module Serialbench
  module Parsers
    class OgaParser < BaseParser
      def parse_dom(xml_string)
        require 'oga'
        Oga.parse_xml(xml_string)
      end

      def parse_sax(xml_string, handler = nil)
        require 'oga'
        handler ||= DefaultSaxHandler.new
        Oga.sax_parse_xml(xml_string, handler)
        handler
      end

      def generate_xml(document, options = {})
        require 'oga'
        document.to_xml
      end

      def supports_streaming?
        true
      end

      protected

      def library_require_name
        'oga'
      end

      def detect_version
        require 'oga'
        Oga::VERSION
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
        false
      end

      # Default SAX handler for Oga
      class DefaultSaxHandler
        attr_reader :elements_processed, :text_nodes_processed

        def initialize
          @elements_processed = 0
          @text_nodes_processed = 0
        end

        def on_element(namespace, name, attributes = {})
          @elements_processed += 1
        end

        def on_text(text)
          @text_nodes_processed += 1 unless text.strip.empty?
        end

        def on_cdata(text)
          @text_nodes_processed += 1 unless text.strip.empty?
        end

        def on_comment(text)
          # Handle comments
        end

        def on_processing_instruction(name, text)
          # Handle processing instructions
        end
      end
    end
  end
end
