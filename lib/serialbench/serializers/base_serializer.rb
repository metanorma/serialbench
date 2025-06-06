# frozen_string_literal: true

module Serialbench
  module Serializers
    class BaseSerializer
      def initialize
        # Override in subclasses
      end

      def available?
        raise NotImplementedError, 'Subclasses must implement #available?'
      end

      def name
        raise NotImplementedError, 'Subclasses must implement #name'
      end

      def version
        raise NotImplementedError, 'Subclasses must implement #version'
      end

      def format
        raise NotImplementedError, 'Subclasses must implement #format'
      end

      def parse(data)
        raise NotImplementedError, 'Subclasses must implement #parse'
      end

      def generate(object)
        raise NotImplementedError, 'Subclasses must implement #generate'
      end

      def stream_parse(data, &block)
        # Default implementation falls back to regular parsing
        # Override in subclasses that support streaming
        result = parse(data)
        yield(:document, result) if block_given?
        result
      end

      def supports_streaming?
        # Override in subclasses that support streaming
        false
      end

      protected

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
