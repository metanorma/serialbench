# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Serialbench::Models::RunMetadata do
  let(:fixture_yaml_path) { 'spec/fixtures/run_metadata.yml' }
  let(:fixture_yaml) { IO.read(fixture_yaml_path) }

  it 'round-trips fixture file' do
    original = described_class.from_yaml(fixture_yaml)
    round_tripped = described_class.from_yaml(original.to_yaml)

    expect(round_tripped.created_at).to eq(original.created_at)
    expect(round_tripped.benchmark_config_path).to eq(original.benchmark_config_path)
    expect(round_tripped.environment_config_path).to eq(original.environment_config_path)
    expect(round_tripped.tags).to eq(original.tags)
  end
end
