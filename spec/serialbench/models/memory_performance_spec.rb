# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Serialbench::Models::MemoryPerformance do
  let(:fixture_yaml_path) { 'spec/fixtures/memory_performance.yml' }
  let(:fixture_yaml) { IO.read(fixture_yaml_path) }

  it 'round-trips fixture file' do
    original = described_class.from_yaml(fixture_yaml)
    round_tripped = described_class.from_yaml(original.to_yaml)

    expect(round_tripped.adapter).to eq(original.adapter)
    expect(round_tripped.format).to eq(original.format)
    expect(round_tripped.data_size).to eq(original.data_size)
    expect(round_tripped.total_allocated).to eq(original.total_allocated)
    expect(round_tripped.total_retained).to eq(original.total_retained)
    expect(round_tripped.allocated_memory).to eq(original.allocated_memory)
    expect(round_tripped.retained_memory).to eq(original.retained_memory)
  end
end
