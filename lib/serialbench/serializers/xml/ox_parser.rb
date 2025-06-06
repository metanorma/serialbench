# frozen_string_literal: true

require_relative 'base_parser'

module Serialbench
  module Parsers
    class OxParser < BaseParser
      def parse_dom(xml_string)
        require 'ox'
        Ox.parse(xml_string)
      end

      def parse_sax(xml_string, handler = nil)
        require 'ox'
        require 'stringio'
        handler ||= OxSaxHandler.new
        Ox.sax_parse(handler, StringIO.new(xml_string))
        handler
      end

      def generate_xml(document, options = {})
        require 'ox'
        indent = options.fetch(:indent, 0)
        Ox.dump(document, indent: indent)
      end

      def supports_streaming?
        true
      end

      # SAX handler for Ox
      class OxSaxHandler < (defined?(::Ox) ? ::Ox::Sax : Object)
        attr_reader :elements_processed, :text_nodes_processed

        def initialize
          @elements_processed = 0
          @text_nodes_processed = 0
        end

        def start_element(name)
          @elements_processed += 1
        end

        def end_element(name)
          # Process end element
        end

        def text(value)
          @text_nodes_processed += 1 unless value.strip.empty?
        end

        def attr(name, value)
          # Process attribute
        end
      end

      protected

      def library_require_name
        'ox'
      end
    end
  end
end
