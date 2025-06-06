# frozen_string_literal: true

require_relative 'base_parser'

module Serialbench
  module Parsers
    class RexmlParser < BaseParser
      def parse_dom(xml_string)
        require 'rexml/document'
        REXML::Document.new(xml_string)
      end

      def parse_sax(xml_string, handler = nil)
        require 'rexml/parsers/sax2parser'
        handler ||= DefaultSaxHandler.new
        parser = REXML::Parsers::SAX2Parser.new(xml_string)
        parser.listen(handler)
        parser.parse
        handler
      rescue LoadError
        # Fallback if SAX2 is not available
        require 'rexml/document'
        doc = REXML::Document.new(xml_string)
        handler ||= DefaultSaxHandler.new
        # Simulate SAX events by walking the document
        doc.root.each_recursive do |element|
          if element.is_a?(REXML::Element)
            handler.start_element(nil, element.name, element.name, element.attributes)
            handler.end_element(nil, element.name, element.name)
          elsif element.is_a?(REXML::Text)
            handler.characters(element.to_s)
          end
        end
        handler
      end

      def generate_xml(document, options = {})
        require 'rexml/document'
        indent = options.fetch(:indent, 0)
        output = String.new
        if indent > 0
          document.write(output, indent)
        else
          document.write(output)
        end
        output
      end

      def supports_streaming?
        true
      end

      protected

      def library_require_name
        'rexml/document'
      end

      def detect_version
        require 'rexml/rexml'
        REXML::VERSION
      rescue LoadError, NameError
        'built-in'
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
    end

    # Default SAX handler for REXML - only define if REXML SAX is available
    begin
      require 'rexml/sax2listener'

      class DefaultSaxHandler
        include ::REXML::SAX2Listener

        attr_reader :elements_processed, :text_nodes_processed

        def initialize
          @elements_processed = 0
          @text_nodes_processed = 0
        end

        def start_element(uri, localname, qname, attributes)
          @elements_processed += 1
        end

        def characters(text)
          @text_nodes_processed += 1 unless text.strip.empty?
        end

        def end_element(uri, localname, qname)
          # Element processing complete
        end
      end
    rescue LoadError
      # SAX2Listener not available, define a simple handler
      class DefaultSaxHandler
        attr_reader :elements_processed, :text_nodes_processed

        def initialize
          @elements_processed = 0
          @text_nodes_processed = 0
        end

        def start_element(uri, localname, qname, attributes)
          @elements_processed += 1
        end

        def characters(text)
          @text_nodes_processed += 1 unless text.strip.empty?
        end

        def end_element(uri, localname, qname)
          # Element processing complete
        end
      end
    end
  end
end
