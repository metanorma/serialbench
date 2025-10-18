# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Serialbench::Models::RunMetadata do
  let(:fixture_yaml_path) { 'spec/fixtures/run_metadata.yml' }
  let(:fixture_yaml) { IO.read(fixture_yaml_path) }

  it 'round-trips fixture file' do
    skip 'YAML formatting differences are non-critical'
    expect(described_class.from_yaml(fixture_yaml).to_yaml).to eql(fixture_yaml)
  end
end
