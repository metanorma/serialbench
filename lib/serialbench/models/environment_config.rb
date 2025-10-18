# frozen_string_literal: true

require 'lutaml/model'
require_relative '../ruby_build_manager'

module Serialbench
  module Models
    # ---
    # name: docker-ruby-3.2
    # kind: docker
    # created_at: '2025-06-13T15:18:43+08:00'
    # ruby_build_tag: "3.2.4"
    # description: Docker environment for Ruby 3.2 benchmarks
    # docker:
    #   image: 'ruby:3.2-slim'
    #   dockerfile: '../../docker/Dockerfile.ubuntu'

    class DockerEnvConfig < Lutaml::Model::Serializable
      attribute :image, :string
      attribute :dockerfile, :string

      key_value do
        map 'image', to: :image
        map 'dockerfile', to: :dockerfile
      end
    end

    # ---
    # name: ruby-324-asdf
    # kind: asdf
    # created_at: '2025-06-12T22:54:43+08:00'
    # ruby_build_tag: 3.2.4
    # description: ASDF environment
    # asdf:
    #   auto_install: true
    class AsdfEnvConfig < Lutaml::Model::Serializable
      attribute :auto_install, :boolean, default: -> { true }

      key_value do
        map 'auto_install', to: :auto_install
      end
    end

    class EnvironmentConfig < Lutaml::Model::Serializable
      attribute :name, :string
      attribute :kind, :string
      attribute :created_at, :string, default: -> { Time.now.utc.iso8601 }
      attribute :ruby_build_tag, :string, values:
        RubyBuildManager.list_definitions
      attribute :description, :string
      attribute :docker, DockerEnvConfig
      attribute :asdf, AsdfEnvConfig

      key_value do
        map 'name', to: :name
        map 'description', to: :description
        map 'kind', to: :kind
        map 'created_at', to: :created_at
        map 'ruby_build_tag', to: :ruby_build_tag
        map 'docker', to: :docker
        map 'asdf', to: :asdf
      end

      def to_file(file_path)
        File.write(file_path, to_yaml)
      end

      def self.from_file(file_path)
        from_yaml(IO.read(file_path))
      end
    end
  end
end
