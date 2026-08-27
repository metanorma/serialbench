# frozen_string_literal: true

require 'fileutils'
require 'open3'
require_relative 'base_cli'
require_relative '../models/platform'

module Serialbench
  module Cli
    # Deep module for CI platform bootstrapping: one interface, internally
    # handles vcpkg, bundler config, DLL staging, and source builds across
    # all twelve runner platforms. Replaces the platform-specific YAML
    # steps that were scattered across the benchmark workflow.
    class CiCli < BaseCli
      desc 'prepare', 'Bootstrap the current platform for benchmarking'
      long_desc <<~DESC
        Detects the runner platform via GITHUB_RUNNER_PLATFORM (or local
        detection) and performs whatever setup is needed: vcpkg packages,
        bundler build flags, DLL staging, and source builds for platforms
        where precompiled gems are unavailable.

        Sets environment variables via GitHub Actions $GITHUB_ENV and
        $GITHUB_PATH when running in CI; prints export lines otherwise.
      DESC
      def prepare
        platform_name = ENV['GITHUB_RUNNER_PLATFORM']
        platform_name ||= Serialbench::Models::Platform.current_local.platform_string

        say "Preparing platform: #{platform_name}", :cyan

        os, = Serialbench::Models::Platform.parse_github_platform(platform_name)

        case os
        when 'windows' then prepare_windows(platform_name)
        when 'linux' then prepare_linux(platform_name)
        when 'macos' then prepare_macos
        else
          say "No specific preparation needed for #{os}", :yellow
        end

        say '✅ Platform prepared', :green
      rescue StandardError => e
        say "❌ Platform preparation failed: #{e.message}", :red
        exit 1
      end

      private

      def github_env(key, value)
        if ENV['GITHUB_ENV'] && File.writable?(ENV['GITHUB_ENV'])
          File.open(ENV['GITHUB_ENV'], 'a') { |f| f.puts "#{key}=#{value}" }
        else
          puts "export #{key}=\"#{value}\""
        end
      end

      def github_path(path)
        if ENV['GITHUB_PATH'] && File.writable?(ENV['GITHUB_PATH'])
          File.open(ENV['GITHUB_PATH'], 'a') { |f| f.puts path }
        else
          puts "export PATH=\"#{path}:$PATH\""
        end
      end

      def prepare_windows(platform_name)
        arch = platform_name.include?('-arm') ? 'arm64-windows' : 'x64-windows'
        vcpkg_root = "C:/vcpkg/installed/#{arch}"

        say '  Installing vcpkg packages (libxml2, libxslt)...', :white
        run_quiet("vcpkg install libxml2:#{arch} libxslt:#{arch}")

        say '  Configuring bundler for system libxml2...', :white
        FileUtils.mkdir_p('.bundle')
        bundler_config = <<~YAML
          ---
          BUNDLE_BUILD__LIBXML___RUBY: "--with-xml2-dir=#{vcpkg_root} --with-xml2-include=#{vcpkg_root}/include/libxml2 --with-xml2-lib=#{vcpkg_root}/lib"
          BUNDLE_BUILD__NOKOGIRI: "--use-system-libraries --with-xml2-include=#{vcpkg_root}/include/libxml2 --with-xml2-lib=#{vcpkg_root}/lib --with-xslt-include=#{vcpkg_root}/include/libxslt --with-xslt-lib=#{vcpkg_root}/lib --with-zlib-dir=#{vcpkg_root}"
        YAML
        File.write('.bundle/config', bundler_config)

        say '  Staging vcpkg DLLs beside ruby.exe...', :white
        ruby_bin = File.dirname(RbConfig.ruby)
        Dir["#{vcpkg_root}/bin/*.dll"].each { |dll| FileUtils.cp(dll, ruby_bin) }
        github_path("#{vcpkg_root}/bin")
      end

      def prepare_linux(platform_name)
        # Ubuntu 22.04's glibc predates the precompiled leptris gem's build
        # host; build the library from the gem's tagged source.
        return unless platform_name.start_with?('ubuntu-22')

        say '  Building libleptris from source (Ubuntu 22.04 glibc)...', :white

        version = Gem::Specification.find_by_name('leptris')&.version.to_s
        tag = resolve_leptris_tag(version)
        say "    leptris #{version} from tag #{tag}", :white

        Dir.mktmpdir do |tmp|
          run_quiet("curl -sL https://github.com/leptris/leptris/archive/refs/tags/#{tag}.tar.gz | tar xz -C #{tmp}")
          source_dir = File.join(tmp, "leptris-#{tag.delete_prefix('v')}")
          build_dir = File.join(tmp, 'build')
          run_quiet("cmake -S #{source_dir} -B #{build_dir} " \
                    '-DLEPTRIS_BUILD_SHARED=ON -DLEPTRIS_BUILD_STATIC=OFF -DBUILD_TESTING=OFF ' \
                    '-DLEPTRIS_BUILD_CLI=OFF -DLEPTRIS_BUILD_BENCHMARKS=OFF -DLEPTRIS_BUILD_MAN_PAGES=OFF ' \
                    '-DLEPTRIS_ENABLE_UTF8PROC=OFF -DLEPTRIS_ENABLE_ICONV=OFF')
          run_quiet("cmake --build #{build_dir} -j#{Etc.nprocessors}")

          lib = Dir[File.join(build_dir, '**', 'libleptris.so*')].first
          raise 'libleptris build produced no shared library' unless lib

          target = File.join('/usr', 'local', 'lib', File.basename(lib))
          FileUtils.cp(lib, target)
          run_quiet('ldconfig')
          github_env('LEPTRIS_LIB_PATH', target)
          say "    Built #{target}", :green
        end
      end

      def prepare_macos
        say '  Installing libxml2 and libxslt via Homebrew...', :white
        run_quiet('brew install libxml2 libxslt 2>/dev/null || true')
      end

      def resolve_leptris_tag(version)
        tags_json, = Open3.capture2('curl', '-s',
                                    'https://api.github.com/repos/leptris/leptris/tags?per_page=100')
        tags = tags_json.scan(/"v\d+\.\d+\.\d+"/).map { |t| t.delete_prefix('"').delete_suffix('"') }
        candidates = tags.select { |t| Gem::Version.new(t.delete_prefix('v')) <= Gem::Version.new(version) }
        candidates.max_by { |t| Gem::Version.new(t.delete_prefix('v')) }
      end

      def run_quiet(command)
        stdout, stderr, status = Open3.capture3(command)
        return stdout if status.success?

        raise "Command failed (#{status.exitstatus}): #{command}\n#{stderr[0, 500]}"
      end
    end
  end
end
