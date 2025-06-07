# frozen_string_literal: true

require 'thor'
require 'json'
require 'yaml'
require 'fileutils'

module Serialbench
  # Thor-based command line interface for Serialbench
  class Cli < Thor
    include Thor::Actions

    desc 'benchmark', 'Run serialization benchmarks'
    long_desc <<~DESC
      Run the complete benchmark suite for all available serialization libraries.

      This command will test parsing, generation, streaming, and memory usage
      across XML, JSON, and TOML formats using all available libraries.
    DESC
    option :formats, type: :array, default: %w[xml json yaml toml],
                     desc: 'Formats to benchmark (xml, json, yaml, toml)'
    option :output_format, type: :string, default: 'all',
                           desc: 'Output format: all, json, yaml, html'
    option :parsing_only, type: :boolean, default: false,
                          desc: 'Run only parsing benchmarks'
    option :generation_only, type: :boolean, default: false,
                             desc: 'Run only generation benchmarks'
    option :streaming_only, type: :boolean, default: false,
                            desc: 'Run only streaming benchmarks'
    option :memory_only, type: :boolean, default: false,
                         desc: 'Run only memory usage benchmarks'
    option :iterations, type: :numeric, default: 10,
                        desc: 'Number of benchmark iterations'
    option :warmup, type: :numeric, default: 3,
                    desc: 'Number of warmup iterations'
    def benchmark
      say 'Serialbench - Comprehensive Serialization Performance Tests', :green
      say '=' * 70, :green

      # Validate formats
      valid_formats = %w[xml json yaml toml]
      invalid_formats = options[:formats] - valid_formats
      unless invalid_formats.empty?
        say "Invalid formats: #{invalid_formats.join(', ')}", :red
        say "Valid formats: #{valid_formats.join(', ')}", :yellow
        exit 1
      end

      # Convert format strings to symbols
      formats = options[:formats].map(&:to_sym)

      # Show available serializers
      show_available_serializers(formats)

      # Run benchmarks
      runner_options = {
        formats: formats,
        iterations: options[:iterations],
        warmup: options[:warmup]
      }

      runner = Serialbench::BenchmarkRunner.new(**runner_options)

      begin
        results = run_selected_benchmarks(runner)
        save_results(results)
        show_summary(results) unless %w[json yaml].include?(options[:output_format])
      rescue StandardError => e
        say "Error running benchmarks: #{e.message}", :red
        say e.backtrace.first(5).join("\n"), :red if ENV['DEBUG']
        exit 1
      end
    end

    desc 'list', 'List available serializers'
    long_desc <<~DESC
      Display all available serialization libraries grouped by format.

      Shows which libraries are installed and available for benchmarking,
      along with their versions.
    DESC
    option :format, type: :string, desc: 'Show only serializers for specific format'
    def list
      say 'Available Serializers', :green
      say '=' * 30, :green

      if options[:format]
        format_sym = options[:format].to_sym
        serializers = Serialbench::Serializers.available_for_format(format_sym)

        if serializers.empty?
          say "No available serializers for format: #{options[:format]}", :yellow
        else
          show_serializers_for_format(format_sym, serializers)
        end
      else
        %i[xml json yaml toml].each do |format|
          serializers = Serialbench::Serializers.available_for_format(format)
          next if serializers.empty?

          show_serializers_for_format(format, serializers)
          say ''
        end
      end
    end

    desc 'version', 'Show Serialbench version'
    def version
      say "Serialbench version #{Serialbench::VERSION}", :green
    end

    desc 'merge_results INPUT_DIRS... OUTPUT_DIR', 'Merge benchmark results from multiple runs'
    long_desc <<~DESC
      Merge benchmark results from multiple Ruby versions or different environments.

      INPUT_DIRS should contain results.json files from different benchmark runs.
      OUTPUT_DIR will contain the merged results and comparative reports.

      Example:
        serialbench merge_results ruby-3.0/results ruby-3.1/results ruby-3.2/results merged_output/
    DESC
    def merge_results(*args)
      if args.length < 2
        say 'Error: Need at least one input directory and one output directory', :red
        say 'Usage: serialbench merge_results INPUT_DIRS... OUTPUT_DIR', :yellow
        exit 1
      end

      output_dir = args.pop
      input_dirs = args

      say "Merging benchmark results from #{input_dirs.length} directories to #{output_dir}", :green

      begin
        merger = Serialbench::ResultMerger.new
        merged_file = merger.merge_directories(input_dirs, output_dir)
        say "Results merged successfully to: #{merged_file}", :green
      rescue StandardError => e
        say "Error merging results: #{e.message}", :red
        exit 1
      end
    end

    desc 'github_pages INPUT_DIRS... OUTPUT_DIR', 'Generate GitHub Pages HTML from multiple benchmark runs'
    long_desc <<~DESC
      Merge benchmark results from multiple Ruby versions and generate a GitHub Pages compatible HTML report.

      INPUT_DIRS should contain results.json files from different benchmark runs.
      OUTPUT_DIR will contain index.html and styles.css ready for GitHub Pages deployment.

      This command combines merge_results and HTML generation in one step.

      Example:
        serialbench github_pages ruby-3.0/results ruby-3.1/results ruby-3.2/results docs/
    DESC
    def github_pages(*args)
      if args.length < 2
        say 'Error: Need at least one input directory and one output directory', :red
        say 'Usage: serialbench github_pages INPUT_DIRS... OUTPUT_DIR', :yellow
        exit 1
      end

      output_dir = args.pop
      input_dirs = args

      say "Generating GitHub Pages from #{input_dirs.length} benchmark directories", :green

      begin
        merger = Serialbench::ResultMerger.new

        # Merge results
        say 'Step 1: Merging benchmark results...', :yellow
        merger.merge_directories(input_dirs, output_dir)

        # Generate GitHub Pages HTML
        say 'Step 2: Generating GitHub Pages HTML...', :yellow
        files = merger.generate_github_pages_html(output_dir)

        say 'GitHub Pages generated successfully!', :green
        say 'Files created:', :cyan
        say "  HTML: #{files[:html]}", :white
        say "  CSS: #{files[:css]}", :white
        say '', :white
        say 'To deploy to GitHub Pages:', :cyan
        say '1. Commit and push the generated files to your repository', :white
        say '2. Enable GitHub Pages in repository settings', :white
        say '3. Set source to the branch containing these files', :white
      rescue StandardError => e
        say "Error generating GitHub Pages: #{e.message}", :red
        exit 1
      end
    end

    desc 'generate_reports DATA_FILE', 'Generate reports from benchmark data'
    long_desc <<~DESC
      Generate HTML and AsciiDoc reports from existing benchmark data.

      DATA_FILE should be a JSON file containing benchmark results.
    DESC
    def generate_reports(data_file)
      say "Generating reports from data in #{data_file}", :green

      unless File.exist?(data_file)
        say "Data file does not exist: #{data_file}", :red
        exit 1
      end

      begin
        Serialbench.generate_reports_from_data(data_file)
        say 'Reports generated successfully!', :green
      rescue StandardError => e
        say "Error generating reports: #{e.message}", :red
        exit 1
      end
    end

    private

    def show_available_serializers(formats)
      say "\nAvailable serializers:", :cyan

      formats.each do |format|
        serializers = Serialbench::Serializers.available_for_format(format)
        next if serializers.empty?

        serializer_names = serializers.map do |serializer_class|
          serializer = serializer_class.new
          "#{serializer.name} v#{serializer.version}"
        end

        say "  #{format.upcase}: #{serializer_names.join(', ')}", :white
      end

      say "\nTest data sizes: small, medium, large", :cyan
      say ''
    end

    def show_serializers_for_format(format, serializers)
      say "#{format.upcase}:", :cyan

      serializers.each do |serializer_class|
        serializer = serializer_class.new
        features = []
        features << 'streaming' if serializer.supports_streaming?
        features << 'built-in' if %w[json rexml psych].include?(serializer.name)

        feature_text = features.empty? ? '' : " (#{features.join(', ')})"
        say "  ✓ #{serializer.name} v#{serializer.version}#{feature_text}", :green
      end
    end

    def run_selected_benchmarks(runner)
      results = { environment: runner.environment_info }

      if options[:parsing_only]
        say 'Running parsing benchmarks...', :yellow
        results[:parsing] = runner.run_parsing_benchmarks
      elsif options[:generation_only]
        say 'Running generation benchmarks...', :yellow
        results[:generation] = runner.run_generation_benchmarks
      elsif options[:streaming_only]
        say 'Running streaming benchmarks...', :yellow
        results[:streaming] = runner.run_streaming_benchmarks
      elsif options[:memory_only]
        say 'Running memory benchmarks...', :yellow
        results[:memory_usage] = runner.run_memory_benchmarks
      else
        say 'Running all benchmarks...', :yellow
        results = runner.run_all_benchmarks
      end

      results
    end

    def save_results(results)
      case options[:output_format]
      when 'json'
        save_json_results(results)
      when 'yaml'
        save_yaml_results(results)
      when 'html'
        generate_html_reports(results)
      else
        # Generate all formats
        save_json_results(results)
        save_yaml_results(results)
        generate_html_reports(results)
      end

      show_generated_files
    end

    def save_json_results(results)
      FileUtils.mkdir_p('results/data')

      # Add Ruby version to results
      results[:ruby_version] = RUBY_VERSION
      results[:ruby_platform] = RUBY_PLATFORM
      results[:timestamp] = Time.now.iso8601

      File.write('results/data/results.json', JSON.pretty_generate(results))
      say 'JSON results saved to: results/data/results.json', :green
    end

    def save_yaml_results(results)
      FileUtils.mkdir_p('results/data')

      # Add Ruby version to results
      results[:ruby_version] = RUBY_VERSION
      results[:ruby_platform] = RUBY_PLATFORM
      results[:timestamp] = Time.now.iso8601

      File.write('results/data/results.yaml', results.to_yaml)
      say 'YAML results saved to: results/data/results.yaml', :green
    end

    def generate_html_reports(results)
      say 'Generating reports...', :yellow
      report_files = Serialbench.generate_reports(results)

      say 'Reports generated:', :green
      say "  HTML: #{report_files[:html]}", :white
      say "  CSS: #{report_files[:css]}", :white
    end

    def show_generated_files
      case options[:output_format]
      when 'json'
        say 'Files generated:', :cyan
        say '  JSON: results/data/results.json', :white
      when 'yaml'
        say 'Files generated:', :cyan
        say '  YAML: results/data/results.yaml', :white
      when 'html'
        say 'Files generated:', :cyan
        say '  HTML: results/reports/benchmark_report.html', :white
        say '  Charts: results/charts/*.svg', :white
      else
        say 'Files generated:', :cyan
        say '  JSON: results/data/results.json', :white
        say '  YAML: results/data/results.yaml', :white
        say '  HTML: results/reports/benchmark_report.html', :white
        say '  Charts: results/charts/*.svg', :white
      end
    end

    def show_summary(results)
      return unless results[:parsing] || results[:generation]

      say "\n" + '=' * 50, :green
      say 'BENCHMARK SUMMARY', :green
      say '=' * 50, :green

      show_parsing_summary(results[:parsing]) if results[:parsing]

      show_generation_summary(results[:generation]) if results[:generation]

      return unless results[:memory_usage]

      show_memory_summary(results[:memory_usage])
    end

    def show_parsing_summary(parsing_results)
      say "\nParsing Performance (operations/second):", :cyan

      %i[small medium large].each do |size|
        next unless parsing_results[size]

        say "\n  #{size.capitalize} files:", :yellow

        # Flatten the nested structure and sort by performance
        flattened_results = []
        parsing_results[size].each do |format, serializers|
          serializers.each do |serializer_name, data|
            flattened_results << ["#{format}/#{serializer_name}", data]
          end
        end

        sorted_results = flattened_results.sort_by { |_, data| -data[:iterations_per_second] }

        sorted_results.each do |serializer_name, data|
          ops_per_sec = data[:iterations_per_second].round(2)
          say "    #{serializer_name}: #{ops_per_sec} ops/sec", :white
        end
      end
    end

    def show_generation_summary(generation_results)
      say "\nGeneration Performance (operations/second):", :cyan

      %i[small medium large].each do |size|
        next unless generation_results[size]

        say "\n  #{size.capitalize} files:", :yellow

        # Flatten the nested structure and sort by performance
        flattened_results = []
        generation_results[size].each do |format, serializers|
          serializers.each do |serializer_name, data|
            flattened_results << ["#{format}/#{serializer_name}", data]
          end
        end

        sorted_results = flattened_results.sort_by { |_, data| -data[:iterations_per_second] }

        sorted_results.each do |serializer_name, data|
          ops_per_sec = data[:iterations_per_second].round(2)
          say "    #{serializer_name}: #{ops_per_sec} ops/sec", :white
        end
      end
    end

    def show_memory_summary(memory_results)
      say "\nMemory Usage (MB):", :cyan

      %i[small medium large].each do |size|
        next unless memory_results[size]

        say "\n  #{size.capitalize} files:", :yellow

        # Flatten the nested structure and sort by memory usage (ascending)
        flattened_results = []
        memory_results[size].each do |format, serializers|
          serializers.each do |serializer_name, data|
            flattened_results << ["#{format}/#{serializer_name}", data]
          end
        end

        sorted_results = flattened_results.sort_by { |_, data| data[:allocated_memory] }

        sorted_results.each do |serializer_name, data|
          memory_mb = (data[:allocated_memory] / 1024.0 / 1024.0).round(2)
          say "    #{serializer_name}: #{memory_mb} MB", :white
        end
      end
    end
  end
end
