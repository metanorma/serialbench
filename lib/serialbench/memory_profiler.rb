# frozen_string_literal: true

module Serialbench
  class MemoryProfiler
    def self.profile(&block)
      return yield unless defined?(::MemoryProfiler)

      ::MemoryProfiler.report(&block)
    end

    def self.available?
      require 'memory_profiler'
      defined?(::MemoryProfiler) ? true : false
    rescue LoadError
      false
    end

    def self.format_report(report)
      return 'Memory profiling not available' unless report

      {
        total_allocated: report.total_allocated,
        total_retained: report.total_retained,
        allocated_memory: report.total_allocated_memsize,
        retained_memory: report.total_retained_memsize,
        allocated_objects_by_gem: report.allocated_memory_by_gem,
        retained_objects_by_gem: report.retained_memory_by_gem
      }
    end
  end
end
