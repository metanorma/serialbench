# frozen_string_literal: true

require_relative 'base_xml_serializer'

module Serialbench
  module Serializers
    module Xml
      class NokogiriSerializer < BaseXmlSerializer
        def name
          'nokogiri'
        end

        def parse(xml_string)
          require 'nokogiri'
          Nokogiri::XML(xml_string)
        end

        def generate(data)
          require 'nokogiri'
          # If data is already a Nokogiri document, convert to string
          if data.respond_to?(:to_xml)
            data.to_xml(indent: 2)
          else
            # Create a simple XML structure from hash-like data
            builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
              build_xml_from_data(xml, data)
            end
            builder.to_xml
          end
        end

        def parse_streaming(xml_string, &block)
          require 'nokogiri'

          handler = StreamingHandler.new(&block)
          parser = Nokogiri::XML::SAX::Parser.new(handler)
          parser.parse(xml_string)
          handler.elements_processed
        end

        def supports_streaming?
          true
        end

        def version
          return 'unknown' unless available?

          require 'nokogiri'
          Nokogiri::VERSION
        end

        protected

        def library_require_name
          'nokogiri'
        end

        private

        def build_xml_from_data(xml, data, root_name = 'root')
          case data
          when Hash
            xml.send(sanitize_element_name(root_name)) do
              data.each do |key, value|
                build_xml_from_data(xml, value, sanitize_element_name(key.to_s))
              end
            end
          when Array
            data.each_with_index do |item, index|
              build_xml_from_data(xml, item, "item_#{index}")
            end
          else
            # Use a safe method that always works
            element_name = sanitize_element_name(root_name)
            if xml.respond_to?(element_name)
              xml.send(element_name, data.to_s)
            else
              # Fallback: create element manually
              xml.tag!(element_name, data.to_s)
            end
          end
        end

        def sanitize_element_name(name)
          # Ensure element name is valid XML and safe to use as method name
          sanitized = name.to_s.gsub(/[^a-zA-Z0-9_]/, '_')
          # Ensure it starts with a letter
          sanitized = "element_#{sanitized}" if sanitized.empty? || sanitized =~ /\A\d/
          # Avoid conflicts with common Nokogiri methods
          reserved_words = %w[text comment cdata parent children attributes namespace]
          sanitized = "data_#{sanitized}" if reserved_words.include?(sanitized)
          sanitized
        end

        # SAX handler for streaming
        class StreamingHandler
          attr_reader :elements_processed

          def initialize(&block)
            require 'nokogiri'
            @block = block
            @elements_processed = 0
            @current_element = nil
            @element_stack = []
          end

          def start_element(name, attributes = [])
            @elements_processed += 1
            attrs = Hash[attributes]
            @current_element = { name: name, attributes: attrs, children: [], text: '' }
            @element_stack.push(@current_element)
          end

          def end_element(name)
            element = @element_stack.pop
            if @element_stack.empty?
              @block&.call(element) if @block
            else
              @element_stack.last[:children] << element
            end
          end

          def characters(string)
            return if string.strip.empty?

            @element_stack.last[:text] += string if @element_stack.any?
          end

          def cdata_block(string)
            @element_stack.last[:text] += string if @element_stack.any?
          end
        end
      end
    end
  end
end
