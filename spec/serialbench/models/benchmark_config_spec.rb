# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Serialbench::Models::BenchmarkConfig do
  let(:fixture_yaml_path) { 'spec/fixtures/benchmark_config.yml' }
  let(:fixture_yaml) { IO.read(fixture_yaml_path) }

  it 'round-trips fixture file' do
    original = described_class.from_yaml(fixture_yaml)
    round_tripped = described_class.from_yaml(original.to_yaml)

    expect(round_tripped.name).to eq(original.name)
    expect(round_tripped.description).to eq(original.description)
    expect(round_tripped.data_sizes).to eq(original.data_sizes)
    expect(round_tripped.formats).to eq(original.formats)
    expect(round_tripped.warmup).to eq(original.warmup)
    expect(round_tripped.operations).to eq(original.operations)

    # Verify iterations
    expect(round_tripped.iterations.small).to eq(original.iterations.small)
    expect(round_tripped.iterations.medium).to eq(original.iterations.medium)
    expect(round_tripped.iterations.large).to eq(original.iterations.large)
  end
end
