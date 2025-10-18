# frozen_string_literal: true

require_relative 'base_xml_serializer'

module Serialbench
  module Serializers
    module Xml
      class RexmlSerializer < BaseXmlSerializer
        def available?
          require_library('rexml/document')
        end

        def name
          'rexml'
        end

        def version
          require 'rexml/rexml'
          REXML::VERSION
        rescue LoadError, NameError
          'built-in'
        end

        def parse(xml_string)
          require 'rexml/document'
          REXML::Document.new(xml_string)
        end

        def generate(data, options = {})
          require 'rexml/document'

          # If data is already a REXML::Document, use it directly
          if data.is_a?(REXML::Document)
            document = data
          else
            # Convert Hash/other data to XML document
            document = REXML::Document.new
            root = document.add_element('root')
            hash_to_xml(data, root)
          end

          indent = options.fetch(:indent, 0)
          output = String.new
          if indent.positive?
            document.write(output, indent)
          else
            document.write(output)
          end
          output
        end

        def stream_parse(xml_string, &block)
          require 'rexml/parsers/sax2parser'
          handler = SaxHandler.new(&block)
          parser = REXML::Parsers::SAX2Parser.new(xml_string)
          parser.listen(handler)
          parser.parse
          handler.result
        rescue LoadError
          # Fallback if SAX2 is not available
          require 'rexml/document'
          doc = REXML::Document.new(xml_string)
          handler = SaxHandler.new(&block)
          # Simulate SAX events by walking the document
          doc.root.each_recursive do |element|
            if element.is_a?(REXML::Element)
              handler.start_element(nil, element.name, element.name, element.attributes)
              handler.end_element(nil, element.name, element.name)
            elsif element.is_a?(REXML::Text)
              handler.characters(element.to_s)
            end
          end
          handler.result
        end

        def supports_streaming?
          false
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

        private

        def hash_to_xml(data, parent)
          case data
          when Hash
            data.each do |key, value|
              element = parent.add_element(key.to_s)
              hash_to_xml(value, element)
            end
          when Array
            data.each_with_index do |item, index|
              element = parent.add_element("item_#{index}")
              hash_to_xml(item, element)
            end
          else
            parent.text = data.to_s
          end
        end
      end

      # SAX handler for REXML streaming
      class SaxHandler
        attr_reader :result, :elements_processed, :text_nodes_processed

        def initialize(&block)
          @block = block
          @elements_processed = 0
          @text_nodes_processed = 0
          @result = nil
        end

        def start_element(_uri, _localname, qname, attributes)
          @elements_processed += 1
          @block&.call(:start_element, { name: qname, attributes: attributes })
        end

        def characters(text)
          return if text.strip.empty?

          @text_nodes_processed += 1
          @block&.call(:text, text)
        end

        def end_element(_uri, _localname, qname)
          @block&.call(:end_element, { name: qname })
        end
      end

      # Include SAX2Listener if available
      begin
        require 'rexml/sax2listener'
        SaxHandler.include(::REXML::SAX2Listener)
      rescue LoadError
        # SAX2Listener not available, handler works without it
      end
    end
  end
end
