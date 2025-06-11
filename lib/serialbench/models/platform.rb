# frozen_string_literal: true

require 'rbconfig'

module Serialbench
  module Models
    class Platform
      attr_reader :runtime, :os, :arch, :ruby_version, :variant

      def initialize(runtime:, ruby_version:, variant: nil)
        @runtime = runtime.to_s
        @ruby_version = ruby_version
        @variant = variant
        @os = detect_os
        @arch = detect_arch
      end

      def self.docker(ruby_version:, variant:)
        new(runtime: :docker, ruby_version: ruby_version, variant: variant)
      end

      def self.local(ruby_version:)
        new(runtime: :local, ruby_version: ruby_version)
      end

      def self.current_local(ruby_version: RUBY_VERSION)
        new(runtime: :local, ruby_version: ruby_version)
      end

      def platform_string
        case @runtime
        when 'docker'
          raise ArgumentError, "Docker platform requires variant" unless @variant
          "docker-#{@variant}-#{@arch}-ruby-#{major_minor_version}"
        when 'local'
          "local-#{@os}-#{@arch}-ruby-#{@ruby_version}"
        else
          raise ArgumentError, "Unknown runtime: #{@runtime}"
        end
      end

      def tags
        base_tags = [@runtime, @arch, "ruby-#{major_minor_version}"]

        case @runtime
        when 'docker'
          base_tags << @variant if @variant
        when 'local'
          base_tags << @os
        end

        base_tags
      end

      def docker?
        @runtime == 'docker'
      end

      def local?
        @runtime == 'local'
      end

      def to_hash
        {
          'runtime' => @runtime,
          'os' => @os,
          'arch' => @arch,
          'ruby_version' => @ruby_version,
          'variant' => @variant,
          'platform_string' => platform_string,
          'tags' => tags
        }.reject { |_, v| v.nil? }
      end

      def ==(other)
        other.is_a?(Platform) && platform_string == other.platform_string
      end

      def hash
        platform_string.hash
      end

      private

      def detect_os
        case RbConfig::CONFIG['host_os']
        when /darwin/i
          'macos'
        when /linux/i
          'linux'
        when /mswin|mingw|cygwin/i
          'windows'
        else
          'unknown'
        end
      end

      def detect_arch
        case RbConfig::CONFIG['host_cpu']
        when /x86_64|amd64/i
          'x86_64'
        when /aarch64|arm64/i
          'arm64'
        when /arm/i
          'arm'
        else
          'unknown'
        end
      end

      def major_minor_version
        @ruby_version.split('.')[0..1].join('.')
      end
    end
  end
end
