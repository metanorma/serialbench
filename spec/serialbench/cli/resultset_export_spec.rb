# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/serialbench/cli/resultset_cli'
require 'fileutils'

RSpec.describe Serialbench::Cli::ResultsetCli do
  let(:temp_dir) { Dir.mktmpdir }
  let(:resultset_path) { File.join(temp_dir, 'test_set') }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  def write_run(name, ruby_version, platform_string: nil)
    run_dir = File.join(temp_dir, name)
    FileUtils.mkdir_p(run_dir)

    yaml = File.read(File.expand_path('../../fixtures/result.yml', __dir__))
    yaml = yaml.gsub('platform_string: docker-ruby-3.0', "platform_string: #{platform_string || "docker-#{name}"}")
               .gsub('ruby_build_tag: 3.0.7', "ruby_build_tag: #{ruby_version}")
    yaml = yaml.sub('  kind: docker', "  kind: docker\n  ruby_version: #{ruby_version}")

    File.write(File.join(run_dir, 'results.yaml'), yaml)
    run_dir
  end

  it 'exports the dashboard payload and raw YAML for a resultset' do
    resultset = Serialbench::Models::ResultSet.new(
      name: 'export-test',
      description: 'export command spec'
    )
    resultset.add_result(write_run('run-a', '3.4.8'))
    resultset.add_result(write_run('run-b', '3.3.12'))
    resultset.save(resultset_path)

    json_path = File.join(temp_dir, 'payload.json')
    raw_dir = File.join(temp_dir, 'data')

    described_class.start(['export-data', resultset_path, json_path, "--raw-data-dir=#{raw_dir}"])

    payload = JSON.parse(File.read(json_path))

    expect(payload['environments'].keys)
      .to contain_exactly('linux-arm64-ruby-3.4.8', 'linux-arm64-ruby-3.3.12')
    expect(payload['metadata']['total_runs']).to eq(2)

    rexml = payload['combined_results']['parsing']['small']['xml']['rexml']
    expect(rexml['linux-arm64-ruby-3.4.8']['iterations_per_second']).to be_a(Numeric)

    expect(File).to exist(File.join(raw_dir, 'resultset.yaml'))
    expect(Dir[File.join(raw_dir, '*.yaml')].size).to eq(3)
  end

  it 'keys environments by the CI runner label when platform_string is runner-shaped' do
    resultset = Serialbench::Models::ResultSet.new(
      name: 'runner-identity',
      description: 'env identity spec'
    )
    resultset.add_result(write_run('ci-a', '3.4.8', platform_string: 'macos-26-ruby-3.4.8'))
    resultset.add_result(write_run('ci-b', '3.4.8', platform_string: 'macos-15-intel-ruby-3.4.8'))
    resultset.save(resultset_path)

    json_path = File.join(temp_dir, 'payload.json')

    described_class.start(['export-data', resultset_path, json_path])

    payload = JSON.parse(File.read(json_path))

    expect(payload['environments'].keys)
      .to contain_exactly('macos-26-ruby-3.4.8', 'macos-15-intel-ruby-3.4.8')
  end
end
