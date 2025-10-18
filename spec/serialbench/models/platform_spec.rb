# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Serialbench::Models::Platform do
  let(:fixture_yaml_path) { 'spec/fixtures/platform.yml' }
  let(:fixture_yaml) { IO.read(fixture_yaml_path) }

  it 'round-trips fixture file' do
    original = described_class.from_yaml(fixture_yaml)
    round_tripped = described_class.from_yaml(original.to_yaml)

    expect(round_tripped.platform_string).to eq(original.platform_string)
    expect(round_tripped.kind).to eq(original.kind)
    expect(round_tripped.os).to eq(original.os)
    expect(round_tripped.arch).to eq(original.arch)
    expect(round_tripped.ruby_version).to eq(original.ruby_version)
    expect(round_tripped.ruby_platform).to eq(original.ruby_platform)
    expect(round_tripped.ruby_build_tag).to eq(original.ruby_build_tag)
  end
end
