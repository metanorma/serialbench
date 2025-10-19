# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/serialbench/models/result_set'
require_relative '../../../lib/serialbench/models/result'
require 'tempfile'
require 'fileutils'

RSpec.describe Serialbench::Models::ResultSet do
  let(:temp_dir) { Dir.mktmpdir }
  let(:resultset_path) { File.join(temp_dir, 'test_resultset') }
  let(:result_path) { File.join(temp_dir, 'test_result') }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe '#add_result' do
    let(:resultset) do
      described_class.new(
        name: 'test_set',
        description: 'Test result set'
      )
    end

    context 'when result has missing platform information' do
      it 'raises an ArgumentError with a helpful message' do
        FileUtils.mkdir_p(result_path)

        # Create a result YAML file without platform information
        result_yaml = <<~YAML
          metadata:
            created_at: "2025-10-19T10:00:00Z"
            benchmark_config_path: "/path/to/config.yml"
            environment_config_path: "/path/to/env.yml"
          environment_config:
            name: test-env
            kind: local
            created_at: "2025-10-19T09:00:00Z"
            ruby_build_tag: "3.2.0"
          benchmark_config:
            benchmark_name: test-benchmark
            formats:
              - json
          benchmark_result:
            serializers: []
        YAML

        File.write(File.join(result_path, 'results.yaml'), result_yaml)

        expect {
          resultset.add_result(result_path)
        }.to raise_error(ArgumentError, /missing platform information/)
      end
    end

    context 'when result has missing environment_config' do
      it 'raises an ArgumentError with a helpful message' do
        FileUtils.mkdir_p(result_path)

        # Create a result YAML file without environment_config
        result_yaml = <<~YAML
          platform:
            platform_string: test-platform
            kind: local
            os: macos
            arch: arm64
          metadata:
            created_at: "2025-10-19T10:00:00Z"
            benchmark_config_path: "/path/to/config.yml"
            environment_config_path: "/path/to/env.yml"
          benchmark_config:
            benchmark_name: test-benchmark
            formats:
              - json
          benchmark_result:
            serializers: []
        YAML

        File.write(File.join(result_path, 'results.yaml'), result_yaml)

        expect {
          resultset.add_result(result_path)
        }.to raise_error(ArgumentError, /missing environment_config/)
      end
    end

    context 'when result has missing benchmark_config' do
      it 'raises an ArgumentError with a helpful message' do
        FileUtils.mkdir_p(result_path)

        # Create a result YAML file without benchmark_config
        result_yaml = <<~YAML
          platform:
            platform_string: test-platform
            kind: local
            os: macos
            arch: arm64
          metadata:
            created_at: "2025-10-19T10:00:00Z"
            benchmark_config_path: "/path/to/config.yml"
            environment_config_path: "/path/to/env.yml"
          environment_config:
            name: test-env
            kind: local
            created_at: "2025-10-19T09:00:00Z"
            ruby_build_tag: "3.2.0"
          benchmark_result:
            serializers: []
        YAML

        File.write(File.join(result_path, 'results.yaml'), result_yaml)

        expect {
          resultset.add_result(result_path)
        }.to raise_error(ArgumentError, /missing benchmark_config/)
      end
    end

    context 'when result has all required fields' do
      it 'adds the result successfully' do
        FileUtils.mkdir_p(result_path)

        # Create a complete result YAML file
        result_yaml = <<~YAML
          platform:
            platform_string: test-platform
            kind: local
            os: macos
            arch: arm64
            ruby_build_tag: "3.2.0"
          metadata:
            created_at: "2025-10-19T10:00:00Z"
            benchmark_config_path: "/path/to/config.yml"
            environment_config_path: "/path/to/env.yml"
          environment_config:
            name: test-env
            kind: local
            created_at: "2025-10-19T09:00:00Z"
            ruby_build_tag: "3.2.0"
          benchmark_config:
            benchmark_name: test-benchmark
            formats:
              - json
            iterations:
              small: 5
            data_sizes:
              - small
          benchmark_result:
            serializers: []
            parsing: []
            generation: []
            memory: []
        YAML

        File.write(File.join(result_path, 'results.yaml'), result_yaml)

        expect {
          resultset.add_result(result_path)
        }.not_to raise_error

        expect(resultset.results.size).to eq(1)
      end
    end
  end
end
