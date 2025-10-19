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

      key_value do
        map 'platform_string', to: :platform_string
        map 'kind', to: :kind
        map 'os', to: :os
        map 'arch', to: :arch
        map 'ruby_version', to: :ruby_version
        map 'ruby_platform', to: :ruby_platform
        map 'ruby_build_tag', to: :ruby_build_tag
      end

      def self.current_local(ruby_version: nil)
        version = ruby_version || RUBY_VERSION

        # Check for GitHub Actions runner platform
        github_platform = ENV['GITHUB_RUNNER_PLATFORM']
        if github_platform
          os, arch = parse_github_platform(github_platform)
          platform_string = "#{github_platform}-ruby-#{version}"
        else
          os = detect_os
          arch = detect_arch
          platform_string = "local-#{version}"
        end

        new(
          platform_string: platform_string,
          kind: 'local',
          os: os,
          arch: arch,
          ruby_version: version,
          ruby_build_tag: version
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

      def self.parse_github_platform(platform_name)
        # Parse GitHub Actions runner platform names
        # Examples: ubuntu-latest, ubuntu-24.04-arm, macos-13, macos-15-large, macos-14, macos-15

        case platform_name
        when /^ubuntu.*-arm$/
          ['linux', 'arm64']
        when /^ubuntu/
          ['linux', 'x86_64']
        when /^macos-(13|15-large)$/
          ['macos', 'x86_64']
        when /^macos-(14|15)$/
          ['macos', 'arm64']
        else
          # Fallback to automatic detection
          [detect_os, detect_arch]
        end
      end
    end
  end
end
