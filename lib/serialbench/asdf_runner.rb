# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'open3'

module Serialbench
  # Handles ASDF-based benchmark execution
  class AsdfRunner
    class AsdfError < StandardError; end

    def initialize(config)
      @config = config
      @output_dir = config.output_dir
      validate_asdf_available
    end

    # Prepare Ruby versions via ASDF
    def prepare
      puts '💎 Preparing Ruby versions via ASDF...'

      # Ensure output directory exists
      FileUtils.mkdir_p(@output_dir)
      cleanup_output_dir

      installed_versions = get_installed_ruby_versions
      missing_versions = @config.ruby_versions - installed_versions

      if missing_versions.any?
        if @config.auto_install
          install_missing_versions(missing_versions)
        else
          raise AsdfError,
                "Missing Ruby versions: #{missing_versions.join(', ')}. Set auto_install: true to install automatically."
        end
      end

      # Install gems for each Ruby version
      install_gems_for_all_versions

      puts '✅ All Ruby versions are prepared with gems installed'
    end

    # Run benchmarks on all Ruby versions
    def benchmark
      puts '🚀 Running benchmarks...'

      successful_runs = 0
      failed_runs = []

      @config.ruby_versions.each do |ruby_version|
        if run_benchmark(ruby_version)
          successful_runs += 1
        else
          failed_runs << ruby_version
        end
      end

      puts "✅ Completed #{successful_runs} benchmark runs"

      puts "⚠️  Failed runs: #{failed_runs.join(', ')}" if failed_runs.any?

      raise AsdfError, 'No successful benchmark runs' if successful_runs == 0

      # Process results
      process_results(successful_runs)
    end

    private

    # Validate ASDF is available
    def validate_asdf_available
      raise AsdfError, 'ASDF is not installed or not available in PATH' unless system('asdf --version > /dev/null 2>&1')

      # Check if ruby plugin is installed
      return if system('asdf plugin list | grep -q ruby')

      raise AsdfError, 'ASDF ruby plugin is not installed. Run: asdf plugin add ruby'
    end

    # Clean up output directory
    def cleanup_output_dir
      if Dir.exist?(@output_dir)
        puts "🧹 Cleaning up previous results in #{@output_dir}"
        FileUtils.rm_rf(@output_dir)
      end
      FileUtils.mkdir_p(@output_dir)
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
        install_log = File.join(@output_dir, "install-ruby-#{version}.log")

        success = system("asdf install ruby #{version} > #{install_log} 2>&1")

        if success
          puts "✅ Installed Ruby #{version}"
        else
          puts "❌ Failed to install Ruby #{version} (see #{install_log})"
          raise AsdfError, "Failed to install Ruby #{version}"
        end
      end
    end

    # Install gems for all Ruby versions
    def install_gems_for_all_versions
      puts '📦 Installing gems for all Ruby versions...'

      @config.ruby_versions.each do |ruby_version|
        puts "🔧 Installing gems for Ruby #{ruby_version}..."

        # Ensure output directory exists
        FileUtils.mkdir_p(@output_dir)

        # Create temporary directory for this Ruby version
        temp_dir = File.join(@output_dir, "temp-ruby-#{ruby_version}")
        FileUtils.mkdir_p(temp_dir)

        # Copy necessary files to temp directory (but not Gemfile.lock to avoid conflicts)
        FileUtils.cp('Gemfile', temp_dir)
        FileUtils.cp('serialbench.gemspec', temp_dir) if File.exist?('serialbench.gemspec')

        # Copy lib directory since gemspec requires it
        FileUtils.cp_r('lib', temp_dir) if Dir.exist?('lib')

        # Install gems in temp directory
        gem_install_log = File.expand_path(File.join(@output_dir, "gems-ruby-#{ruby_version}.log"))

        # Set up isolated gem environment for this Ruby version
        gem_home = File.join(temp_dir, 'gem_home')
        FileUtils.mkdir_p(gem_home)

        # Create a standalone shell script to install gems in isolated environment
        install_script = File.join(temp_dir, 'install_gems.sh')

        # Write the script content directly using File.write with explicit content
        ruby_path = "~/.asdf/installs/ruby/#{ruby_version}/bin"
        script_content = "#!/bin/bash\n" +
                         "set -e\n" +
                         "echo 'Starting gem installation for Ruby #{ruby_version}'\n" +
                         "cd #{File.expand_path(temp_dir)}\n" +
                         "echo 'Setting up gem environment'\n" +
                         "export GEM_HOME=#{File.expand_path(gem_home)}\n" +
                         "export GEM_PATH=#{File.expand_path(gem_home)}\n" +
                         "export PATH=#{File.expand_path(gem_home)}/bin:#{ruby_path}:$PATH\n" +
                         "unset BUNDLE_GEMFILE\n" +
                         "unset BUNDLE_PATH\n" +
                         "unset BUNDLE_BIN_PATH\n" +
                         "unset RUBYOPT\n" +
                         "echo 'Cleaning up previous installations'\n" +
                         "rm -f Gemfile.lock\n" +
                         "rm -rf .bundle vendor\n" +
                         "echo 'Installing bundler without bundle setup'\n" +
                         "BUNDLE_GEMFILE= #{ruby_path}/gem install bundler --no-document\n" +
                         "echo 'Installing rake'\n" +
                         "BUNDLE_GEMFILE= #{ruby_path}/gem install rake --no-document\n" +
                         "echo 'Running bundle install'\n" +
                         "#{ruby_path}/bundle install --verbose\n" +
                         "echo 'Gem installation completed successfully'\n"

        File.write(install_script, script_content)
        FileUtils.chmod(0o755, install_script)

        puts "   📦 Installing gems for Ruby #{ruby_version}..."
        unless system("#{install_script} >> #{gem_install_log} 2>&1")
          puts "❌ Failed to install gems for Ruby #{ruby_version} (see #{gem_install_log})"
          raise AsdfError, "Failed to install gems for Ruby #{ruby_version}"
        end

        puts "✅ Gems installed for Ruby #{ruby_version}"

        # Clean up temp directory
        FileUtils.rm_rf(temp_dir)
      end
    end

    # Run benchmark for specific Ruby version
    def run_benchmark(ruby_version)
      # Generate combined platform string: asdf-os-arch-interpreter-version
      platform_string = generate_platform_string('asdf', ruby_version)
      result_dir = File.join(@output_dir, platform_string)

      puts "🏃 Running benchmarks for Ruby #{ruby_version}..."
      puts "   📁 Results will be saved to: #{result_dir}"

      FileUtils.mkdir_p(result_dir)
      benchmark_log = File.join(result_dir, 'benchmark.log')

      # Create temporary directory for benchmark execution
      temp_dir = File.join(result_dir, 'temp-benchmark')
      FileUtils.mkdir_p(temp_dir)

      # Copy necessary files to temp directory
      FileUtils.cp('Gemfile', temp_dir)
      FileUtils.cp('serialbench.gemspec', temp_dir) if File.exist?('serialbench.gemspec')

      # Copy lib directory and other necessary files
      FileUtils.cp_r('lib', temp_dir)
      FileUtils.cp_r('exe', temp_dir) if Dir.exist?('exe')
      FileUtils.cp_r('config', temp_dir) if Dir.exist?('config')

      # Create .tool-versions file in temp directory
      tool_versions_file = File.join(temp_dir, '.tool-versions')
      File.write(tool_versions_file, "ruby #{ruby_version}\n")

      # Run benchmark (gems should already be installed during prepare phase)
      puts '   🔧 Running benchmark command...'
      puts "   📝 Benchmark output will be logged to: #{benchmark_log}"
      puts '   ⏳ This may take several minutes...'

      # Change to temp directory and run benchmark there
      # The benchmark command outputs to results/ directory by default
      benchmark_cmd = [
        'cd', temp_dir, '&&',
        'asdf', 'exec', 'bundle', 'install', '--quiet', '&&',
        'asdf', 'exec', 'ruby', '-I', 'lib', 'exe/serialbench', 'benchmark', 'execute',
        File.expand_path(@config.benchmark_config)
      ].join(' ')

      # Run the command and capture output using Open3
      success = false
      absolute_benchmark_log = File.expand_path(benchmark_log)

      Dir.chdir(temp_dir) do
        # First install dependencies
        puts '   📦 Installing dependencies...'
        system('asdf exec bundle install --quiet')

        # Then run the benchmark using Open3 for better output handling
        puts '   🚀 Starting benchmark execution...'
        cmd = ['asdf', 'exec', 'ruby', '-I', 'lib', 'exe/serialbench', 'benchmark', 'execute',
               File.expand_path(@config.benchmark_config)]

        Open3.popen3(*cmd) do |stdin, stdout, stderr, wait_thr|
          stdin.close

          # Write both stdout and stderr to log file
          File.open(absolute_benchmark_log, 'w') do |log_file|
            # Read stdout and stderr in separate threads
            stdout_thread = Thread.new do
              stdout.each_line do |line|
                log_file.write(line)
                log_file.flush
                # Also print progress to console
                puts "      #{line.chomp}" if line.include?('Testing') || line.include?('Running')
              end
            end

            stderr_thread = Thread.new do
              stderr.each_line do |line|
                log_file.write("STDERR: #{line}")
                log_file.flush
              end
            end

            # Wait for both threads to complete
            stdout_thread.join
            stderr_thread.join
          end

          # Wait for the process to complete
          success = wait_thr.value.success?
        end
      end

      # Check for success by looking at the log file for success message
      success_detected = false
      if File.exist?(absolute_benchmark_log)
        log_content = File.read(absolute_benchmark_log)
        success_detected = log_content.include?('✅ Benchmark run completed successfully!')
      end

      if success && success_detected
        puts "✅ Completed Ruby #{ruby_version}"

        # The benchmark saves results to results/runs/ directory
        # Look for the actual results directory that was created
        results_runs_dir = File.join(temp_dir, 'results', 'runs')
        if Dir.exist?(results_runs_dir)
          # Find the results directory (should be something like local-macos-arm64-ruby-X.X.X)
          result_subdirs = Dir.glob(File.join(results_runs_dir, '*')).select { |d| Dir.exist?(d) }

          if result_subdirs.any?
            # Copy the results to our expected location
            result_subdirs.each do |subdir|
              subdir_name = File.basename(subdir)
              target_dir = File.join(result_dir, 'results', 'runs', subdir_name)
              FileUtils.mkdir_p(File.dirname(target_dir))
              FileUtils.cp_r(subdir, target_dir)
              puts "   📊 Results copied to: #{target_dir}"
            end
          end
        end

        # Clean up temp directory
        FileUtils.rm_rf(temp_dir)
        true
      else
        puts "❌ Failed Ruby #{ruby_version} (see #{benchmark_log})"
        if File.exist?(benchmark_log)
          puts "   🔍 Check log file for details: #{benchmark_log}"
          # Show last few lines of log for debugging
          log_lines = File.readlines(benchmark_log).last(5)
          puts '   📄 Last few lines of log:'
          log_lines.each { |line| puts "      #{line.chomp}" }
        end

        # Clean up temp directory even on failure
        FileUtils.rm_rf(temp_dir)
        false
      end
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
      puts "📊 Individual benchmark results available in:"
      result_dirs.each do |dir|
        puts "   - #{dir}"
      end
      puts ""
      puts "💡 To create a comparison report, use:"
      puts "   serialbench runset new multi-ruby-comparison"
      result_dirs.each do |dir|
        result_name = File.basename(dir)
        puts "   serialbench runset add-result multi-ruby-comparison #{result_name}"
      end
      puts "   serialbench runset build-site multi-ruby-comparison"
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

    # Generate GitHub Pages
    def generate_github_pages(result_dirs)
      puts '📄 Generating GitHub Pages...'

      pages_cmd = [
        'bundle', 'exec', 'serialbench', 'github_pages',
        *result_dirs,
        File.join(@output_dir, '_site')
      ].join(' ')

      raise AsdfError, 'Failed to generate GitHub Pages' unless system(pages_cmd)
    end
  end
end
