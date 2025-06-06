# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

desc 'Run benchmarks'
task :benchmark do
  require_relative 'lib/serialbench'

  puts 'Running XML benchmarks...'
  results = Serialbench.run_benchmarks

  puts "\nGenerating reports..."
  report_files = Serialbench.generate_reports(results)

  puts "\nBenchmark complete!"
  puts 'Reports generated:'
  puts "  HTML: #{report_files[:html]}"
  puts "  AsciiDoc: #{report_files[:asciidoc]}"
  puts "  Charts: #{report_files[:charts].length} SVG files"
end

desc 'Install all XML library dependencies'
task :install_deps do
  gems = %w[ox nokogiri libxml-ruby oga memory_profiler]

  puts 'Installing XML library dependencies...'
  gems.each do |gem_name|
    puts "Installing #{gem_name}..."
    system("gem install #{gem_name}")
  rescue StandardError => e
    puts "Warning: Failed to install #{gem_name}: #{e.message}"
  end
  puts 'Done!'
end

desc 'Check which XML libraries are available'
task :check_libs do
  require_relative 'lib/serialbench'

  runner = Serialbench::BenchmarkRunner.new

  puts 'XML Library Availability Check'
  puts '=' * 40

  runner.parsers.each do |parser|
    status = parser.available? ? '✓ Available' : '✗ Not available'
    version = parser.available? ? " (#{parser.version})" : ''
    puts "#{parser.name.ljust(15)} #{status}#{version}"
  end

  puts "\nMemory profiler: #{Serialbench::MemoryProfiler.available? ? '✓ Available' : '✗ Not available'}"
end

desc 'Clean generated files'
task :clean do
  FileUtils.rm_rf('results')
  puts 'Cleaned generated files'
end

task default: :spec
