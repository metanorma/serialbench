# frozen_string_literal: true

require_relative 'base_xml_serializer'

module Serialbench
  module Serializers
    module Xml
      class OgaSerializer < BaseXmlSerializer
        def name
          'oga'
        end

        def parse(xml_string)
          require 'oga'
          Oga.parse_xml(xml_string)
        end

        def generate(data)
          require 'oga'
          # If data is already an Oga document, convert to string
          if data.respond_to?(:to_xml)
            data.to_xml
          else
            # Create a simple XML structure from hash-like data
            document = Oga::XML::Document.new
            root = build_xml_from_data(data)
            document.children << root
            document.to_xml
          end
        end

        def parse_streaming(xml_string, &block)
          require 'oga'

          handler = StreamingHandler.new(&block)
          parser = Oga::XML::SaxParser.new(handler, xml_string)
          parser.parse
          handler.elements_processed
        end

        def supports_streaming?
          true
        end

        def version
          return 'unknown' unless available?

          require 'oga'
          Oga::VERSION
        end

        def library_require_name
          'oga'
        end

        private

        def build_xml_from_data(data, name = 'root')
          require 'oga'

          case data
          when Hash
            element = Oga::XML::Element.new(name: name)
            data.each do |key, value|
              child = build_xml_from_data(value, key.to_s)
              element.children << child
            end
            element
          when Array
            element = Oga::XML::Element.new(name: name)
            data.each_with_index do |item, index|
              child = build_xml_from_data(item, "item_#{index}")
              element.children << child
            end
            element
          else
            element = Oga::XML::Element.new(name: name)
            text_node = Oga::XML::Text.new(text: data.to_s)
            element.children << text_node
            element
          end
        end

        # SAX handler for streaming
        class StreamingHandler
          attr_reader :elements_processed

          def initialize(&block)
            @block = block
            @elements_processed = 0
            @current_element = nil
            @element_stack = []
          end

          def on_element(namespace, name, attributes = {})
            @elements_processed += 1
            @current_element = { name: name, namespace: namespace, attributes: attributes, children: [], text: '' }
            @element_stack.push(@current_element)
          end

          def on_text(text)
            return if text.strip.empty?

            @element_stack.last[:text] += text if @element_stack.any?
          end

          def on_cdata(text)
            @element_stack.last[:text] += text if @element_stack.any?
          end

          def after_element(namespace, name)
            element = @element_stack.pop
            if @element_stack.empty?
              @block&.call(element) if @block
            else
              @element_stack.last[:children] << element
            end
          end
        end
      end
    end
  end
end
