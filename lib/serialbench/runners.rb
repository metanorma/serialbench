# frozen_string_literal: true

require_relative 'runners/base'
require_relative 'runners/local_runner'
require_relative 'runners/docker_runner'
require_relative 'runners/asdf_runner'

module Serialbench
  # Executes benchmarks in an environment: local, docker, or asdf.
  module Runners
    def self.for(environment_config, environment_config_path)
      runner_class = case environment_config.kind
                     when 'local' then LocalRunner
                     when 'docker' then DockerRunner
                     when 'asdf' then AsdfRunner
                     else raise ArgumentError, "unknown environment kind: #{environment_config.kind}"
                     end

      runner_class.new(environment_config, environment_config_path)
    end
  end
end
