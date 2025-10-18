# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Serialbench::Models::EnvironmentConfig do
  let(:fixture_yaml_path) { 'spec/fixtures/environment_config.yml' }
  let(:fixture_yaml) { IO.read(fixture_yaml_path) }

  it 'round-trips fixture file' do
    original = described_class.from_yaml(fixture_yaml)
    round_tripped = described_class.from_yaml(original.to_yaml)

    expect(round_tripped.name).to eq(original.name)
    expect(round_tripped.kind).to eq(original.kind)
    expect(round_tripped.created_at).to eq(original.created_at)
    expect(round_tripped.ruby_build_tag).to eq(original.ruby_build_tag)
    expect(round_tripped.description).to eq(original.description)

    # Verify docker config if present
    if original.docker
      expect(round_tripped.docker.image).to eq(original.docker.image)
      expect(round_tripped.docker.dockerfile).to eq(original.docker.dockerfile)
    end

    # Verify asdf config if present
    if original.asdf
      expect(round_tripped.asdf.auto_install).to eq(original.asdf.auto_install)
    end
  end
end
