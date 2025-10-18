# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Serialbench::Models::IterationPerformance do
  let(:fixture_yaml_path) { 'spec/fixtures/iteration_performance.yml' }
  let(:fixture_yaml) { IO.read(fixture_yaml_path) }

  it 'round-trips fixture file' do
    original = described_class.from_yaml(fixture_yaml)
    round_tripped = described_class.from_yaml(original.to_yaml)

    expect(round_tripped.adapter).to eq(original.adapter)
    expect(round_tripped.format).to eq(original.format)
    expect(round_tripped.data_size).to eq(original.data_size)
    expect(round_tripped.time_per_iterations).to eq(original.time_per_iterations)
    expect(round_tripped.time_per_iteration).to eq(original.time_per_iteration)
    expect(round_tripped.iterations_per_second).to eq(original.iterations_per_second)
    expect(round_tripped.iterations_count).to eq(original.iterations_count)
  end
end
