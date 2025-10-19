# frozen_string_literal: true

require 'octokit'
require 'yaml'
require 'fileutils'

module Serialbench
  # Manages Ruby-Build definitions from the official ruby-build repository
  class RubyBuildManager
    GITHUB_API_URL = 'https://api.github.com/repos/rbenv/ruby-build/contents/share/ruby-build'
    CACHE_DIR = File.expand_path('~/.serialbench')
    CACHE_FILE = File.join(CACHE_DIR, 'ruby-build-definitions.yaml')

    class << self
      def update_definitions
        puts '🔄 Fetching Ruby-Build definitions from GitHub...'

        definitions = fetch_definitions_from_github
        save_definitions_to_cache(definitions)

        puts "✅ Updated #{definitions.length} Ruby-Build definitions"
        puts "📁 Cache location: #{CACHE_FILE}"

        definitions
      rescue StandardError => e
        raise "Failed to update Ruby-Build definitions: #{e.message}"
      end

      def list_definitions
        load_definitions_from_cache
      end

      def show_definition(tag)
        definitions = load_definitions_from_cache

        raise "Ruby-Build definition '#{tag}' not found. Available definitions: #{definitions.length}" unless definitions.include?(tag)

        {
          tag: tag,
          available: true,
          source: 'ruby-build',
          cache_file: CACHE_FILE
        }
      end

      def validate_tag(tag)
        puts "🔍 Validating Ruby-Build tag: #{tag} against #{CACHE_FILE}"
        return false if tag.nil? || tag.strip.empty?

        definitions = load_definitions_from_cache
        definitions.include?(tag)
      rescue StandardError
        false
      end

      def suggest_current_ruby_tag
        ruby_version = RUBY_VERSION

        # Try exact match first
        return ruby_version if validate_tag(ruby_version)

        # Try common variations
        variations = [
          ruby_version,
          "#{ruby_version}.0",
          "#{ruby_version.split('.')[0..1].join('.')}.0"
        ]

        variations.each do |variation|
          return variation if validate_tag(variation)
        end

        # Return the Ruby version even if not found, user can adjust
        ruby_version
      end

      def cache_exists?
        File.exist?(CACHE_FILE)
      end

      def cache_age
        return nil unless cache_exists?

        Time.now - File.mtime(CACHE_FILE)
      end

      def ensure_cache_exists!
        return if cache_exists?

        raise <<~ERROR
          Ruby-Build definitions cache not found.

          Update the cache first:
            serialbench ruby-build update
        ERROR
      end

      private

      def fetch_definitions_from_github
        # Initialize client with optional authentication
        # Falls back to unauthenticated if GITHUB_TOKEN not set
        client_options = {}
        client_options[:access_token] = ENV['GITHUB_TOKEN'] if ENV['GITHUB_TOKEN']

        client = Octokit::Client.new(client_options)

        contents = client.contents('rbenv/ruby-build', path: 'share/ruby-build')

        # Extract definition names from the file list
        definitions = contents
                      .select { |item| item[:type] == 'file' && item[:name] != 'Makefile' }
                      .map { |item| item[:name] }
                      .sort

        raise 'No Ruby-Build definitions found in GitHub response' if definitions.empty?

        definitions
      rescue Octokit::Error => e
        warn "Warning: Error fetching Ruby-Build definitions from GitHub: #{e.message}"
        warn "Note: Set GITHUB_TOKEN environment variable to avoid rate limits"
        []
      end

      def save_definitions_to_cache(definitions)
        FileUtils.mkdir_p(CACHE_DIR)

        cache_data = {
          'updated_at' => Time.now.utc.iso8601,
          'source' => GITHUB_API_URL,
          'count' => definitions.length,
          'definitions' => definitions
        }

        File.write(CACHE_FILE, cache_data.to_yaml)
      end

      def load_definitions_from_cache
        return [] unless cache_exists?

        cache_data = YAML.load_file(CACHE_FILE)
        cache_data['definitions'] || []
      rescue StandardError => e
        warn "Warning: Failed to load Ruby-Build definitions from cache: #{e.message}"
        []
      end
    end
  end
end
