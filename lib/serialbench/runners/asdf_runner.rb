# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'yaml'
require 'open3'
require 'stringio'
require_relative '../benchmark_runner'
require_relative 'base'

module Serialbench
  # Handles ASDF-based benchmark execution
  module Runners
    class AsdfRunner < Base
      class AsdfError < StandardError; end

      def initialize(environment_config, environment_config_path)
        super
        validate_asdf_available
      end

      # Prepare Ruby versions via ASDF
      def prepare
        puts '💎 Preparing Ruby versions via ASDF...'

        ruby_version = @environment_config.ruby_build_tag
        installed_versions = get_installed_ruby_versions

        unless installed_versions.include?(ruby_version)
          if @environment_config.asdf&.auto_install
            install_missing_versions([ruby_version])
          else
            raise AsdfError,
                  "Missing Ruby version: #{ruby_version}. Set auto_install: true to install automatically."
          end
        end

        # Install gems for the Ruby version
        install_gems_for_version(ruby_version)

        puts '✅ Ruby version is prepared with gems installed'
      end

      # Run benchmark
      def benchmark
        puts '🚀 Running benchmarks...'

        ruby_version = @environment_config.ruby_build_tag

        raise AsdfError, 'Benchmark run failed' unless run_benchmark(ruby_version)

        puts '✅ Completed 1 benchmark runs'
        puts "📁 Individual results are available in: results/runs/#{@environment_name}"
        puts '✅ ASDF benchmark completed successfully!'
        puts "Results saved to: results/runs/#{@environment_name}"
        puts "Generate site: serialbench benchmark build-site results/runs/#{@environment_name}"
      end

      private

      # Validate ASDF is available
      def validate_asdf_available
        unless system('asdf --version > /dev/null 2>&1')
          raise AsdfError,
                'ASDF is not installed or not available in PATH'
        end

        # Check if ruby plugin is installed
        return if system('asdf plugin list | grep -q ruby')

        raise AsdfError, 'ASDF ruby plugin is not installed. Run: asdf plugin add ruby'
      end

      # Get list of installed Ruby versions
      def get_installed_ruby_versions
        output = `asdf list ruby 2>/dev/null`.strip
        return [] if output.empty?

        output.split("\n").map(&:strip).reject(&:empty?).map do |line|
          # Remove leading asterisk and whitespace
          line.gsub(/^\*?\s*/, '')
        end
      end

      # Install missing Ruby versions
      def install_missing_versions(versions)
        puts "📦 Installing missing Ruby versions: #{versions.join(', ')}"

        versions.each do |version|
          puts "🔨 Installing Ruby #{version}..."

          # Create temporary log directory
          Dir.mktmpdir('asdf_install_ruby') do |temp_log_dir|
            # Create a temporary file for logging
            install_log = File.join(temp_log_dir, "install-ruby-#{version}.log")

            success = false
            Dir.chdir(temp_log_dir) do
              success = system("asdf install ruby #{version} > #{install_log} 2>&1")
            end

            if success
              puts "✅ Installed Ruby #{version}"
            else
              puts "❌ Failed to install Ruby #{version} (see #{install_log})"
              raise AsdfError, "Failed to install Ruby #{version}"
            end
          end
        end
      end

      # Install gems for a specific Ruby version
      def install_gems_for_version(ruby_version)
        puts "🔧 Installing gems for Ruby #{ruby_version}..."

        # Create temporary log directory
        temp_log_dir = "results/asdf-#{ruby_version}"
        FileUtils.mkdir_p(temp_log_dir)
        gem_install_log = File.join(temp_log_dir, "gems-ruby-#{ruby_version}.log")

        # Use ASDF to install bundler and the serialbench gem
        puts "   📦 Installing bundler and serialbench for Ruby #{ruby_version}..."
        env = { 'ASDF_RUBY_VERSION' => ruby_version }
        cmd = ['asdf', 'exec', 'gem', 'install', 'bundler', 'serialbench', '--no-document']

        success = system(env, *cmd, out: gem_install_log, err: gem_install_log)
        unless success
          puts "❌ Failed to install gems for Ruby #{ruby_version} (see #{gem_install_log})"
          raise AsdfError, "Failed to install gems for Ruby #{ruby_version}"
        end

        # ASDF doesn't need reshash like rbenv - gems are immediately available
        puts "✅ Gems installed for Ruby #{ruby_version}"
      end

      # Run benchmark for specific Ruby version
      def run_benchmark(benchmark_config, _benchmark_config_path, result_dir)
        puts "🚀 Running benchmark for #{@name}..."

        FileUtils.mkdir_p(result_dir)

        prepare

        ruby_version = @environment_config.ruby_build_tag
        puts "🏃 Running benchmarks for Ruby #{ruby_version}..."
        puts "   📁 Results will be saved to: #{result_dir}"

        benchmark_log = File.join(result_dir, 'benchmark.log')

        # Run benchmark directly using BenchmarkRunner instead of CLI
        puts '   🚀 Starting benchmark execution...'

        # Set ASDF Ruby version for this process
        ENV['ASDF_RUBY_VERSION'] = ruby_version

        # Capture stdout/stderr for logging
        log_output = StringIO.new

        runner = Serialbench::BenchmarkRunner.new(
          benchmark_config: benchmark_config,
          environment_config: @environment_config
        )

        # Run benchmarks and capture output
        puts "   Running benchmarks with #{benchmark_config.iterations} iterations..."

        # Redirect stdout to capture benchmark output
        original_stdout = $stdout
        $stdout = log_output

        results = runner.run_all_benchmarks

        # Restore stdout
        $stdout = original_stdout

        # Save benchmark results to results.yaml
        results_file = File.join(result_dir, 'results.yaml')

        # Create platform string
        require_relative 'models/platform'
        platform = Serialbench::Models::Platform.current_local
        platform_string = "asdf-#{platform.os}-#{platform.arch}-ruby-#{ruby_version}"

        # Create comprehensive results structure with platform and metadata merged in
        full_results = {
          'platform' => {
            'platform_string' => platform_string,
            'type' => 'asdf',
            'os' => platform.os,
            'arch' => platform.arch
          },
          'metadata' => {
            'environment_name' => @environment_name,
            'benchmark_config' => @benchmark_config,
            'created_at' => Time.now.iso8601,
            'tags' => ['asdf', platform.os, platform.arch, "ruby-#{ruby_version}"]
          },
          'environment' => {
            'name' => @environment_name,
            'type' => 'asdf',
            'ruby_build_tag' => ruby_version,
            'created_at' => Time.now.iso8601
          },
          'config' => {
            'benchmark_config' => @benchmark_config,
            'formats' => config['formats'],
            'iterations' => config['iterations'],
            'data_sizes' => config['data_sizes']
          },
          'results' => results
        }

        File.write(results_file, full_results.to_yaml)

        # Save execution log
        File.write(benchmark_log, log_output.string)

        puts "✅ Completed Ruby #{ruby_version}"
        puts "   Results saved to: #{results_file}"
        puts "   Log saved to: #{benchmark_log}"
        true
      rescue StandardError => e
        puts "❌ Failed Ruby #{ruby_version}: #{e.message}"
        File.write(benchmark_log, "Error: #{e.message}\n#{e.backtrace.join("\n")}")
        false
      ensure
        # Clean up environment variable and restore stdout
        ENV.delete('ASDF_RUBY_VERSION')
        $stdout = original_stdout if defined?(original_stdout)
      end

      # Process and merge results
      def process_results(successful_runs)
        puts "📊 Processing #{successful_runs} successful results..."

        # Find all result directories with valid results
        # Look for directories that contain results/runs subdirectories
        result_dirs = Dir.glob(File.join(@output_dir, 'asdf-*')).select do |dir|
          results_runs_dir = File.join(dir, 'results', 'runs')
          Dir.exist?(results_runs_dir) && !Dir.glob(File.join(results_runs_dir, '*')).empty?
        end

        if result_dirs.empty?
          puts '⚠️  No results found for processing, but benchmarks completed successfully!'
          puts "📁 Individual results are available in: #{@output_dir}"
          return
        end

        puts '🎉 Results processed successfully!'
        puts "📁 Results directory: #{@output_dir}"
        puts '📊 Individual benchmark results available in:'
        result_dirs.each do |dir|
          puts "   - #{dir}"
        end
        puts ''
        puts '💡 To create a comparison report, use:'
        puts '   serialbench resultset new multi-ruby-comparison'
        result_dirs.each do |dir|
          result_name = File.basename(dir)
          puts "   serialbench resultset add-result multi-ruby-comparison #{result_name}"
        end
        puts '   serialbench resultset build-site multi-ruby-comparison'
      end

      # Generate combined platform string for directory naming
      # Format: asdf-{os}-{arch}-ruby-{version}
      def generate_platform_string(runner_type, ruby_version)
        # Get OS name
        os = case RUBY_PLATFORM
             when /darwin/
               'macos'
             when /linux/
               'linux'
             when /mswin|mingw|cygwin/
               'windows'
             else
               'unknown'
             end

        # Get architecture (simplified)
        arch = case RUBY_PLATFORM
               when /x86_64|amd64/
                 'x64'
               when /arm64|aarch64/
                 'arm64'
               when /i386|i686/
                 'x86'
               else
                 'unknown'
               end

        "#{runner_type}-#{os}-#{arch}-ruby-#{ruby_version}"
      end
    end
  end
end
