require 'lutaml/model'

module Serialbench
  module Models
    # Configuration for comprehensive benchmarks - Full testing with all data sizes
    # Used by Docker script for complete performance analysis

    # data_sizes:
    #   - small
    #   - medium
    #   - large

    # formats:
    #   - xml
    #   - json
    #   - yaml
    #   - toml

    # iterations:
    #   small: 20
    #   medium: 5
    #   large: 2

    # # Enable memory profiling for comprehensive analysis
    # memory_profiling: true

    # # Standard warmup iterations
    # warmup_iterations: 3

    # # Enable streaming benchmarks where supported
    # streaming_benchmarks: true

    class BenchmarkIteration < Lutaml::Model::Serializable
      attribute :small, :integer, default: -> { 20 }
      attribute :medium, :integer, default: -> { 5 }
      attribute :large, :integer, default: -> { 2 }

      key_value do
        map 'small', to: :small
        map 'medium', to: :medium
        map 'large', to: :large
      end
    end

    class BenchmarkConfig < Lutaml::Model::Serializable
      attribute :name, :string
      attribute :description, :string
      attribute :data_sizes, :string, collection: true, values: %w[small medium large]
      attribute :formats, :string, collection: true, values: %w[xml json yaml toml]
      attribute :iterations, BenchmarkIteration
      attribute :warmup, :integer, default: -> { 1 }
      attribute :operations, :string, collection: true, values: %w[parse generate memory streaming]

      def to_file(file_path)
        File.write(file_path, to_yaml)
      end

      def self.from_file(file_path)
        from_yaml(IO.read(file_path))
      end
    end
  end
end
