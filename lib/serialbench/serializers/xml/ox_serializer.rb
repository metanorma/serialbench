# frozen_string_literal: true

require_relative 'base_xml_serializer'

module Serialbench
  module Serializers
    module Xml
      class OxSerializer < BaseXmlSerializer
        def name
          'ox'
        end

        def parse(xml_string)
          require 'ox'
          Ox.parse(xml_string)
        end

        def generate(data)
          require 'ox'
          Ox.dump(data, indent: 2)
        end

        def parse_streaming(xml_string, &block)
          require 'ox'
          require 'stringio'

          handler = StreamingHandler.new(&block)
          Ox.sax_parse(handler, StringIO.new(xml_string))
          handler.elements_processed
        end

        def supports_streaming?
          true
        end

        def version
          return 'unknown' unless available?

          require 'ox'
          Ox::VERSION
        end

        def library_require_name
          'ox'
        end

        # SAX handler for streaming
        class StreamingHandler < (defined?(::Ox) ? ::Ox::Sax : Object)
          attr_reader :elements_processed

          def initialize(&block)
            @block = block
            @elements_processed = 0
            @current_element = nil
            @element_stack = []
          end

          def start_element(name)
            @elements_processed += 1
            @current_element = { name: name, attributes: {}, children: [], text: '' }
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

          def text(value)
            return if value.strip.empty?

            @element_stack.last[:text] += value if @element_stack.any?
          end

          def attr(name, value)
            @element_stack.last[:attributes][name] = value if @element_stack.any?
          end
        end
      end
    end
  end
end
