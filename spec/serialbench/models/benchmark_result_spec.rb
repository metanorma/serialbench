# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Serialbench::Models::BenchmarkResult do
  let(:fixture_yaml_path) { 'spec/fixtures/benchmark_result.yml' }
  let(:fixture_yaml) { IO.read(fixture_yaml_path) }

  it 'round-trips fixture file' do
    original = described_class.from_yaml(fixture_yaml)
    round_tripped = described_class.from_yaml(original.to_yaml)

    expect(round_tripped.serializers.size).to eq(original.serializers.size)
    expect(round_tripped.parsing.size).to eq(original.parsing.size)
    expect(round_tripped.generation.size).to eq(original.generation.size)
    expect(round_tripped.memory.size).to eq(original.memory.size)
    expect(round_tripped.streaming.size).to eq(original.streaming.size)

    # Verify first serializer as a sample
    expect(round_tripped.serializers.first.format).to eq(original.serializers.first.format)
    expect(round_tripped.serializers.first.name).to eq(original.serializers.first.name)
    expect(round_tripped.serializers.first.version).to eq(original.serializers.first.version)

    # Verify first parsing result as a sample
    expect(round_tripped.parsing.first.adapter).to eq(original.parsing.first.adapter)
    expect(round_tripped.parsing.first.format).to eq(original.parsing.first.format)
    expect(round_tripped.parsing.first.iterations_count).to eq(original.parsing.first.iterations_count)
  end
end
