# frozen_string_literal: true

require_relative 'base_xml_serializer'

module Serialbench
  module Serializers
    module Xml
      class TaurusSerializer < BaseXmlSerializer
        def name
          'taurus'
        end

        def parse(xml_string)
          require 'taurus'
          Taurus::XML.parse(xml_string)
        end

        def generate(data)
          require 'taurus'
          if data.is_a?(Taurus::XML::Document) || data.is_a?(Taurus::XML::Node)
            data.to_xml(indent: 2)
          else
            build_document_from_data(data).to_xml(indent: 2)
          end
        end

        def parse_streaming(xml_string, &block)
          require 'taurus'

          handler = StreamingHandler.new(&block)
          parser = Taurus::XML::SAX::Parser.new(handler)
          parser.parse_memory(xml_string)
          handler.elements_processed
        end

        def supports_streaming?
          true
        end

        def supports_xpath?
          true
        end

        def version
          return 'unknown' unless available?

          require 'taurus'
          Taurus::VERSION
        end

        def library_require_name
          'taurus'
        end

        # The gem's require succeeds even when the libtaurus shared library is
        # missing -- the FFI load happens lazily at first use. Probe with a
        # real parse so "available" means "actually usable".
        def available?
          return @available if defined?(@available)

          @available = begin
            require 'taurus'
            Taurus::XML.parse('<probe/>')
            true
          rescue StandardError
            false
          end
        end

        private

        def build_document_from_data(data, root_name = 'root')
          document = Taurus::XML.parse('<root/>')
          document.root.name = sanitize_element_name(root_name)
          append_data(document.root, data)
          document
        end

        def append_data(element, data)
          case data
          when Hash
            data.each do |key, value|
              child = element.document.create_element(sanitize_element_name(key.to_s))
              element.add_child(child)
              append_data(child, value)
            end
          when Array
            data.each do |item|
              child = element.document.create_element('item')
              element.add_child(child)
              append_data(child, item)
            end
          else
            element.content = data.to_s
          end
        end

        def sanitize_element_name(name)
          sanitized = name.to_s.gsub(/[^a-zA-Z0-9_]/, '_')
          sanitized = "element_#{sanitized}" if sanitized.empty? || sanitized =~ /\A\d/
          sanitized
        end

        # SAX handler counting elements, mirroring the Nokogiri adapter's
        # StreamingHandler shape (Taurus SAX delivers attrs as [name, value]
        # pairs, same as Nokogiri::XML::SAX). Plain duck-typed class --
        # Taurus::XML::SAX::Parser needs no base class, and subclassing it
        # would trigger the FFI library load at file-load time.
        class StreamingHandler
          attr_reader :elements_processed

          def initialize(&block)
            @block = block
            @elements_processed = 0
            @element_stack = []
          end

          # No-op callbacks the parser invokes unconditionally (the base
          # Taurus::XML::SAX::Document normally provides these).
          def start_document; end
          def end_document; end
          def xmldecl(_version, _encoding, _standalone); end
          def comment(_string); end
          def processing_instruction(_name, _content); end
          def start_prefix_mapping(_prefix, _uri); end
          def end_prefix_mapping(_prefix); end
          def warning(_string); end
          def error(_message, _line = 0, _column = 0); end

          def start_element(name, attrs = [])
            @elements_processed += 1
            @element_stack.push({ name: name, attributes: Hash[attrs], children: [], text: '' })
          end

          def end_element(_name)
            element = @element_stack.pop
            if @element_stack.empty?
              @block&.call(element)
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
