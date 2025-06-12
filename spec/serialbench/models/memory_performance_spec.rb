# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Serialbench::Models::MemoryPerformance do
  let(:fixture_yaml_path) { 'spec/fixtures/memory_performance.yml' }
  let(:fixture_yaml) { IO.read(fixture_yaml_path) }

  it 'round-trips fixture file' do
    expect(described_class.from_yaml(fixture_yaml).to_yaml).to eql(fixture_yaml)
  end
end
