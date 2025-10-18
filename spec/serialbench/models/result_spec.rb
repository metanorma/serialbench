# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Serialbench::Models::Result do
  let(:fixture_yaml_path) { 'spec/fixtures/result.yml' }
  let(:fixture_yaml) { IO.read(fixture_yaml_path) }

  it 'round-trips fixture file' do
    original = described_class.from_yaml(fixture_yaml)
    round_tripped = described_class.from_yaml(original.to_yaml)

    # Verify platform
    expect(round_tripped.platform.platform_string).to eq(original.platform.platform_string)
    expect(round_tripped.platform.kind).to eq(original.platform.kind)

    # Verify metadata
    expect(round_tripped.metadata.created_at).to eq(original.metadata.created_at)
    expect(round_tripped.metadata.benchmark_config_path).to eq(original.metadata.benchmark_config_path)
    expect(round_tripped.metadata.environment_config_path).to eq(original.metadata.environment_config_path)

    # Verify configs
    expect(round_tripped.environment_config.name).to eq(original.environment_config.name)
    expect(round_tripped.benchmark_config.name).to eq(original.benchmark_config.name)

    # Verify benchmark result collections
    expect(round_tripped.benchmark_result.serializers.size).to eq(original.benchmark_result.serializers.size)
    expect(round_tripped.benchmark_result.parsing.size).to eq(original.benchmark_result.parsing.size)
  end
end
