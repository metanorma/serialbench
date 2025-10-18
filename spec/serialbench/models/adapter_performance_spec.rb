# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Serialbench::Models::AdapterPerformance do
  let(:fixture_yaml_path) { 'spec/fixtures/adapter_performance.yml' }
  let(:fixture_yaml) { IO.read(fixture_yaml_path) }

  it 'round-trips fixture file' do
    original = described_class.from_yaml(fixture_yaml)
    round_tripped = described_class.from_yaml(original.to_yaml)

    expect(round_tripped.adapter).to eq(original.adapter)
    expect(round_tripped.format).to eq(original.format)
    expect(round_tripped.data_size).to eq(original.data_size)
  end
end
