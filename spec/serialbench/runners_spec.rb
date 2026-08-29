# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'

RSpec.describe Serialbench::Runners do
  def write_env(kind)
    dir = Dir.mktmpdir
    path = File.join(dir, "env-#{kind}.yml")
    attrs = {
      name: "test-#{kind}",
      kind: kind,
      ruby_build_tag: '3.4.0'
    }
    if kind == 'docker'
      attrs[:docker] = Serialbench::Models::DockerEnvConfig.new(image: 'ruby:3.4', dockerfile: 'Dockerfile')
      File.write(File.join(dir, 'Dockerfile'), "FROM ruby:3.4\n")
    end
    config = Serialbench::Models::EnvironmentConfig.new(**attrs)
    File.write(path, config.to_yaml)
    [Serialbench::Models::EnvironmentConfig.from_yaml(File.read(path)), path]
  end

  it "returns LocalRunner for kind 'local'" do
    environment, path = write_env('local')
    expect(described_class.for(environment, path)).to be_a(Serialbench::Runners::LocalRunner)
  end

  it "returns DockerRunner for kind 'docker'" do
    environment, path = write_env('docker')
    begin
      expect(described_class.for(environment, path)).to be_a(Serialbench::Runners::DockerRunner)
    rescue Serialbench::Runners::DockerRunner::DockerError
      skip 'docker absent on this machine; the raise site proves DockerRunner was selected'
    end
  end

  it "selects AsdfRunner for kind 'asdf'" do
    environment, path = write_env('asdf')
    begin
      expect(described_class.for(environment, path)).to be_a(Serialbench::Runners::AsdfRunner)
    rescue Serialbench::Runners::AsdfRunner::AsdfError
      skip 'asdf absent on this machine; the raise site proves AsdfRunner was selected'
    end
  end

  it 'raises for an unknown kind' do
    environment = Serialbench::Models::EnvironmentConfig.new(
      name: 'broken', kind: 'mainframe', ruby_build_tag: '3.4.0'
    )
    path = File.join(Dir.mktmpdir, 'env.yml')
    File.write(path, "kind: mainframe\n")

    expect { described_class.for(environment, path) }
      .to raise_error(ArgumentError, /unknown environment kind: mainframe/)
  end
end

RSpec.describe Serialbench::Cli::EnvironmentCli, '#new' do
  it 'writes a loadable local environment honoring --dir' do
    Dir.mktmpdir do |dir|
      described_class.start(['new', 'local-dev', 'local', '3.4.0', '--dir', dir])

      path = File.join(dir, 'local-dev.yml')
      expect(File).to exist(path)

      config = Serialbench::Models::EnvironmentConfig.from_yaml(File.read(path))
      expect(config.kind).to eq('local')
      expect(config.name).to eq('local-dev')
      expect(config.ruby_build_tag).to eq('3.4.0')
    end
  end
end
