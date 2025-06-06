# frozen_string_literal: true

require_relative 'base_xml_serializer'

module Serialbench
  module Serializers
    module Xml
      class LibxmlSerializer < BaseXmlSerializer
        def name
          'libxml'
        end

        def parse(xml_string)
          require 'libxml'
          LibXML::XML::Parser.string(xml_string).parse
        end

        def generate(data)
          require 'libxml'
          # If data is already a LibXML document, convert to string
          if data.respond_to?(:to_s) && data.class.name.include?('LibXML')
            data.to_s(indent: true)
          else
            # Create a simple XML structure from hash-like data
            doc = LibXML::XML::Document.new
            doc.root = build_xml_from_data(data)
            doc.to_s(indent: true)
          end
        end

        def parse_streaming(xml_string, &block)
          require 'libxml'

          handler = StreamingHandler.new(&block)
          parser = LibXML::XML::SaxParser.string(xml_string)
          parser.callbacks = handler
          parser.parse
          handler.elements_processed
        end

        def supports_streaming?
          true
        end

        def version
          return 'unknown' unless available?

          require 'libxml'
          LibXML::XML::VERSION
        end

        protected

        def library_require_name
          'libxml'
        end

        private

        def build_xml_from_data(data, name = 'root')
          require 'libxml'

          case data
          when Hash
            element = LibXML::XML::Node.new(name.to_s)
            data.each do |key, value|
              child = build_xml_from_data(value, key.to_s)
              element << child
            end
            element
          when Array
            element = LibXML::XML::Node.new(name.to_s)
            data.each_with_index do |item, index|
              child = build_xml_from_data(item, "item_#{index}")
              element << child
            end
            element
          else
            element = LibXML::XML::Node.new(name.to_s)
            element.content = data.to_s
            element
          end
        end

        # SAX handler for streaming
        class StreamingHandler
          include LibXML::XML::SaxParser::Callbacks if defined?(LibXML::XML::SaxParser::Callbacks)

          attr_reader :elements_processed

          def initialize(&block)
            @block = block
            @elements_processed = 0
            @current_element = nil
            @element_stack = []
          end

          def on_start_element(element, attributes)
            @elements_processed += 1
            attrs = Hash[attributes || []]
            @current_element = { name: element, attributes: attrs, children: [], text: '' }
            @element_stack.push(@current_element)
          end

          def on_end_element(element)
            element_data = @element_stack.pop
            if @element_stack.empty?
              @block&.call(element_data) if @block
            else
              @element_stack.last[:children] << element_data
            end
          end

          def on_characters(chars)
            return if chars.strip.empty?

            @element_stack.last[:text] += chars if @element_stack.any?
          end

          def on_cdata_block(cdata)
            @element_stack.last[:text] += cdata if @element_stack.any?
          end
        end
      end
    end
  end
end
