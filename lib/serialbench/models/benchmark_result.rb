# frozen_string_literal: true

require 'lutaml/model'

module Serialbench
  module Models
    class SerializerInformation < Lutaml::Model::Serializable
      attribute :format, :string, values: %w[xml json yaml toml]
      attribute :name, :string
      attribute :version, :string

      key_value do
        map 'format', to: :format
        map 'name', to: :name
        map 'version', to: :version
      end
    end

    class AdapterPerformance < Lutaml::Model::Serializable
      attribute :adapter, :string
      attribute :format, :string, values: %w[xml json yaml toml]
      attribute :data_size, :string, values: %w[small medium large]

      key_value do
        map 'adapter', to: :adapter
        map 'format', to: :format
        map 'data_size', to: :data_size
      end
    end

    class IterationPerformance < AdapterPerformance
      attribute :time_per_iterations, :float
      attribute :time_per_iteration, :float
      attribute :iterations_per_second, :float
      attribute :iterations_count, :integer

      key_value do
        map 'adapter', to: :adapter
        map 'format', to: :format
        map 'data_size', to: :data_size
        map 'time_per_iterations', to: :time_per_iterations
        map 'time_per_iteration', to: :time_per_iteration
        map 'iterations_per_second', to: :iterations_per_second
        map 'iterations_count', to: :iterations_count
      end
    end

    class MemoryPerformance < AdapterPerformance
      attribute :total_allocated, :integer
      attribute :total_retained, :integer
      attribute :allocated_memory, :integer
      attribute :retained_memory, :integer

      key_value do
        map 'adapter', to: :adapter
        map 'format', to: :format
        map 'data_size', to: :data_size
        map 'total_allocated', to: :total_allocated
        map 'total_retained', to: :total_retained
        map 'allocated_memory', to: :allocated_memory
        map 'retained_memory', to: :retained_memory
      end
    end

    class BenchmarkResult < Lutaml::Model::Serializable
      attribute :serializers, SerializerInformation, collection: true
      attribute :parsing, IterationPerformance, collection: true
      attribute :generation, IterationPerformance, collection: true
      attribute :memory, MemoryPerformance, collection: true
      attribute :streaming, IterationPerformance, collection: true

      key_value do
        map 'serializers', to: :serializers
        map 'parsing', to: :parsing
        map 'generation', to: :generation
        map 'memory', to: :memory
        map 'streaming', to: :streaming
      end
    end
  end
end
