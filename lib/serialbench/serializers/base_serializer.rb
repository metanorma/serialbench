require 'set'

# frozen_string_literal: true

require 'singleton'

module Serialbench
  module Serializers
    class BaseSerializer
      include Singleton

      def initialize
        # Override in subclasses
      end

      %w[name version format library_require_name available?].each do |method_name|
        define_method(method_name) do
          self.class.send(method_name)
        end
      end

      def parse(data)
        raise NotImplementedError, 'Subclasses must implement #parse'
      end

      def generate(object)
        raise NotImplementedError, 'Subclasses must implement #generate'
      end

      def stream_parse(data)
        # Default implementation falls back to regular parsing
        # Override in subclasses that support streaming
        result = parse(data)
        yield(:document, result) if block_given?
        result
      end

      # Capabilities: a Set of symbols declaring what this adapter can do.
      # Subclasses override to add symbols; the base handles every query.
      # This replaces the 12+ individual supports_X? predicates.
      def capabilities
        Set.new(%i[dom parse generate])
      end

      def supports?(capability)
        capabilities.include?(capability)
      end

      def supports_streaming?
        supports?(:sax) || supports?(:streaming)
      end

      def require_library(library_name)
        require library_name
        true
      rescue LoadError
        false
      end

      def get_version(constant_path)
        constant_path.split('::').reduce(Object) { |obj, const| obj.const_get(const) }
      rescue NameError
        'unknown'
      end
    end
  end
end
