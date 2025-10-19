# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Serialbench::BenchmarkRunner do
  describe '#run_all_benchmarks' do
    let(:benchmark_config) do
      Serialbench::Models::BenchmarkConfig.new(
        iterations: Serialbench::Models::BenchmarkIteration.new(
          small: 10,
          medium: 5,
          large: 2
        ),
        warmup: 2,
        formats: ['json'],
        data_sizes: ['small']
      )
    end

    let(:environment_config) do
      Serialbench::Models::EnvironmentConfig.new(
        name: 'test-env',
        ruby_version: '3.0.0',
        platform: 'test'
      )
    end

    it 'creates BenchmarkResult with correct attribute names' do
      runner = described_class.new(
        benchmark_config: benchmark_config,
        environment_config: environment_config
      )

      result = runner.run_all_benchmarks

      # Verify that the result has the correct attributes
      expect(result).to be_a(Serialbench::Models::BenchmarkResult)

      # Critical: ensure 'memory' attribute is used, not 'memory_usage'
      # This was the root cause of the GHA failure - using wrong attribute name
      # caused Lutaml::Model to ignore all attributes and serialize as {}
      expect(result.memory).to be_an(Array)
      expect(result.parsing).to be_an(Array)
      expect(result.generation).to be_an(Array)
      expect(result.streaming).to be_an(Array)
      expect(result.serializers).to be_an(Array)
    end

    it 'creates BenchmarkResult that round-trips correctly' do
      runner = described_class.new(
        benchmark_config: benchmark_config,
        environment_config: environment_config
      )

      original = runner.run_all_benchmarks

      # Restore YAML to Psych before serialization
      # The benchmark run may have loaded Syck which overrides YAML
      Object.send(:remove_const, :YAML) if defined?(::YAML)
      require 'psych'
      ::YAML = Psych

      yaml_string = original.to_yaml
      round_tripped = Serialbench::Models::BenchmarkResult.from_yaml(yaml_string)

      # Verify memory attribute is preserved through serialization
      expect(round_tripped.memory).to be_an(Array)
      expect(round_tripped.memory.size).to eq(original.memory.size)
      expect(round_tripped.parsing.size).to eq(original.parsing.size)
      expect(round_tripped.generation.size).to eq(original.generation.size)
      expect(round_tripped.streaming.size).to eq(original.streaming.size)
      expect(round_tripped.serializers.size).to eq(original.serializers.size)
    end
  end
end
