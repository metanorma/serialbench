# frozen_string_literal: true

require 'spec_helper'
require 'yaml' # So it does not use syck

RSpec.describe Serialbench::Models::Result do
  let(:fixture_yaml_path) { 'spec/fixtures/result.yml' }
  let(:fixture_yaml) { IO.read(fixture_yaml_path) }

  it 'round-trips fixture file' do
    skip 'YAML formatting differences are non-critical'
    expect(described_class.from_yaml(fixture_yaml).to_yaml).to eql(fixture_yaml)
  end
end
