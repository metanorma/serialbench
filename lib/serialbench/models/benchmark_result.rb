# frozen_string_literal: true

require 'lutaml/model'

module Serialbench
  module Models
    class SerializerInformation < Lutaml::Model::Serializable
      attribute :format, :string, values: %w[xml json yaml toml]
      attribute :name, :string
      attribute :version, :string
    end

    class AdapterPerformance < Lutaml::Model::Serializable
      attribute :adapter, :string
      attribute :format, :string, values: %w[xml json yaml toml]
      attribute :data_size, :string, values: %w[small medium large]
    end

    class IterationPerformance < AdapterPerformance
      attribute :time_per_iterations, :float
      attribute :time_per_iteration, :float
      attribute :iterations_per_second, :float
      attribute :iterations_count, :integer
    end

    class MemoryPerformance < AdapterPerformance
      attribute :total_allocated, :integer
      attribute :total_retained, :integer
      attribute :allocated_memory, :integer
      attribute :retained_memory, :integer
    end

    class BenchmarkResult < Lutaml::Model::Serializable
      attribute :serializers, SerializerInformation, collection: true
      attribute :parsing, IterationPerformance, collection: true
      attribute :generation, IterationPerformance, collection: true
      attribute :memory, MemoryPerformance, collection: true
      attribute :streaming, IterationPerformance, collection: true
    end
  end
end
