# frozen_string_literal: true

require 'lutaml/model'
require_relative '../ruby_build_manager'

module Serialbench
  module Models
    # platform:
    #   platform_string: docker-ruby-3.0
    #   kind: docker
    #   os: linux
    #   arch: arm64
    #   ruby_build_tag: 3.0.7

    class Platform < Lutaml::Model::Serializable
      attribute :platform_string, :string
      attribute :kind, :string, default: -> { 'local' }
      attribute :os, :string, default: -> { detect_os }
      attribute :arch, :string, default: -> { detect_arch }
      attribute :ruby_version, :string, default: -> { RUBY_VERSION }
      attribute :ruby_platform, :string, default: -> { RUBY_PLATFORM }
      attribute :ruby_build_tag, :string

      def self.current_local
        new(
          platform_string: "local-#{RUBY_VERSION}",
          kind: 'local',
          os: detect_os,
          arch: detect_arch,
          ruby_build_tag: RUBY_VERSION
        )
      end

      def self.detect_os
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

      def self.detect_arch
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
    end
  end
end
