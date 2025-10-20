# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Serialbench::Models::Platform do
  let(:fixture_yaml_path) { 'spec/fixtures/platform.yml' }
  let(:fixture_yaml) { IO.read(fixture_yaml_path) }

  describe 'YAML serialization' do
    it 'round-trips fixture file' do
      original = described_class.from_yaml(fixture_yaml)
      round_tripped = described_class.from_yaml(original.to_yaml)

      expect(round_tripped.platform_string).to eq(original.platform_string)
      expect(round_tripped.kind).to eq(original.kind)
      expect(round_tripped.os).to eq(original.os)
      expect(round_tripped.arch).to eq(original.arch)
      expect(round_tripped.ruby_version).to eq(original.ruby_version)
      expect(round_tripped.ruby_platform).to eq(original.ruby_platform)
      expect(round_tripped.ruby_build_tag).to eq(original.ruby_build_tag)
    end
  end

  describe '.parse_github_platform' do
    it 'parses Ubuntu x86_64 platforms' do
      os, arch = described_class.parse_github_platform('ubuntu-latest')
      expect(os).to eq('linux')
      expect(arch).to eq('x86_64')
    end

    it 'parses Ubuntu ARM platforms' do
      os, arch = described_class.parse_github_platform('ubuntu-24.04-arm')
      expect(os).to eq('linux')
      expect(arch).to eq('arm64')

      os, arch = described_class.parse_github_platform('ubuntu-22.04-arm')
      expect(os).to eq('linux')
      expect(arch).to eq('arm64')
    end

    it 'parses macOS Intel platforms' do
      os, arch = described_class.parse_github_platform('macos-13')
      expect(os).to eq('macos')
      expect(arch).to eq('x86_64')

      os, arch = described_class.parse_github_platform('macos-15-intel')
      expect(os).to eq('macos')
      expect(arch).to eq('x86_64')
    end

    it 'parses macOS ARM platforms' do
      os, arch = described_class.parse_github_platform('macos-14')
      expect(os).to eq('macos')
      expect(arch).to eq('arm64')

      os, arch = described_class.parse_github_platform('macos-15')
      expect(os).to eq('macos')
      expect(arch).to eq('arm64')
    end

    it 'parses Windows platforms' do
      os, arch = described_class.parse_github_platform('windows-latest')
      expect(os).to eq('windows')
      expect(arch).to eq('x86_64')

      os, arch = described_class.parse_github_platform('windows-2022')
      expect(os).to eq('windows')
      expect(arch).to eq('x86_64')
    end
  end

  describe '.current_local' do
    context 'with GITHUB_RUNNER_PLATFORM environment variable' do
      it 'uses GitHub platform parsing for Windows' do
        ENV['GITHUB_RUNNER_PLATFORM'] = 'windows-latest'
        platform = described_class.current_local(ruby_version: '3.4')

        expect(platform.os).to eq('windows')
        expect(platform.arch).to eq('x86_64')
        expect(platform.platform_string).to eq('windows-latest-ruby-3.4')
        expect(platform.kind).to eq('local')

        ENV.delete('GITHUB_RUNNER_PLATFORM')
      end

      it 'uses GitHub platform parsing for Ubuntu' do
        ENV['GITHUB_RUNNER_PLATFORM'] = 'ubuntu-latest'
        platform = described_class.current_local(ruby_version: '3.3')

        expect(platform.os).to eq('linux')
        expect(platform.arch).to eq('x86_64')
        expect(platform.platform_string).to eq('ubuntu-latest-ruby-3.3')

        ENV.delete('GITHUB_RUNNER_PLATFORM')
      end

      it 'uses GitHub platform parsing for macOS' do
        ENV['GITHUB_RUNNER_PLATFORM'] = 'macos-14'
        platform = described_class.current_local(ruby_version: '3.2')

        expect(platform.os).to eq('macos')
        expect(platform.arch).to eq('arm64')
        expect(platform.platform_string).to eq('macos-14-ruby-3.2')

        ENV.delete('GITHUB_RUNNER_PLATFORM')
      end
    end
  end
end
