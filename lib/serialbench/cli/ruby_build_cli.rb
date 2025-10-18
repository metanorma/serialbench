# frozen_string_literal: true

require_relative 'base_cli'
require_relative '../ruby_build_manager'

module Serialbench
  module Cli
    # CLI for managing Ruby-Build definitions
    class RubyBuildCli < BaseCli
      desc 'update', 'Update Ruby-Build definitions from GitHub'
      long_desc <<~DESC
        Fetch the latest Ruby-Build definitions from the official ruby-build repository
        and cache them locally for validation purposes.

        This command is required before using any Ruby-Build validation features.

        Examples:
          serialbench ruby-build update
      DESC
      def update
        say '🔄 Updating Ruby-Build definitions...', :green

        begin
          definitions = RubyBuildManager.update_definitions

          say "✅ Successfully updated #{definitions.length} Ruby-Build definitions", :green
          say "📁 Cache location: #{RubyBuildManager::CACHE_FILE}", :cyan

          # Show some examples
          recent_versions = definitions.select { |d| d.match?(/^3\.[2-4]\.\d+$/) }.last(5)
          if recent_versions.any?
            say "\n📋 Recent Ruby versions available:", :white
            recent_versions.each { |version| say "  #{version}", :cyan }
          end
        rescue StandardError => e
          say "❌ Failed to update Ruby-Build definitions: #{e.message}", :red
          exit 1
        end
      end

      desc 'list [FILTER]', 'List available Ruby-Build definitions'
      long_desc <<~DESC
        List all available Ruby-Build definitions from the local cache.

        Optionally filter the list by providing a filter string.

        Examples:
          serialbench ruby-build list           # List all definitions
          serialbench ruby-build list 3.3       # Filter by "3.3"
          serialbench ruby-build list 3.2.      # Filter by "3.2."
      DESC
      option :limit, type: :numeric, default: 50, desc: 'Maximum number of definitions to show'
      def list(filter = nil)
        definitions = RubyBuildManager.list_definitions(filter: filter)

        if definitions.empty?
          if filter
            say "No Ruby-Build definitions found matching '#{filter}'", :yellow
          else
            say 'No Ruby-Build definitions found in cache', :yellow
            say 'Update the cache first: serialbench ruby-build update', :white
          end
          return
        end

        # Limit results if there are many
        limited_definitions = definitions.first(options[:limit])

        say "Ruby-Build Definitions#{filter ? " (filtered by '#{filter}')" : ''}:", :green
        say '=' * 60, :green

        limited_definitions.each do |definition|
          say "  #{definition}", :cyan
        end

        if definitions.length > options[:limit]
          remaining = definitions.length - options[:limit]
          say "\n... and #{remaining} more definitions", :yellow
          say 'Use --limit to show more results', :white
        end

        say "\nTotal: #{definitions.length} definitions", :white
      rescue StandardError => e
        say "❌ Failed to list Ruby-Build definitions: #{e.message}", :red
        say 'Try updating the cache: serialbench ruby-build update', :white
        exit 1
      end

      desc 'show TAG', 'Show details for a specific Ruby-Build definition'
      long_desc <<~DESC
        Show detailed information about a specific Ruby-Build definition.

        Examples:
          serialbench ruby-build show 3.3.8
          serialbench ruby-build show 3.2.4
      DESC
      def show(tag)
        definition = RubyBuildManager.show_definition(tag)

        say "Ruby-Build Definition: #{tag}", :green
        say '=' * 40, :green
        say "Tag: #{definition[:tag]}", :cyan
        say "Available: #{definition[:available] ? '✅ Yes' : '❌ No'}", :cyan
        say "Source: #{definition[:source]}", :cyan
        say "Cache file: #{definition[:cache_file]}", :white
      rescue StandardError => e
        say "❌ #{e.message}", :red
        say 'Available definitions: serialbench ruby-build list', :white
        exit 1
      end

      desc 'validate TAG', 'Validate a Ruby-Build tag'
      long_desc <<~DESC
        Validate whether a Ruby-Build tag exists in the cached definitions.

        Examples:
          serialbench ruby-build validate 3.3.8
          serialbench ruby-build validate 3.2.4
      DESC
      def validate(tag)
        valid = RubyBuildManager.validate_tag(tag)

        if valid
          say "✅ Ruby-Build tag '#{tag}' is valid", :green
        else
          say "❌ Ruby-Build tag '#{tag}' is not valid", :red

          # Suggest similar tags
          definitions = RubyBuildManager.list_definitions
          similar = definitions.select { |d| d.include?(tag.split('.').first(2).join('.')) }.first(5)

          if similar.any?
            say "\n💡 Similar available tags:", :yellow
            similar.each { |s| say "  #{s}", :cyan }
          end

          exit 1
        end
      rescue StandardError => e
        say "❌ Failed to validate tag: #{e.message}", :red
        say 'Try updating the cache: serialbench ruby-build update', :white
        exit 1
      end

      desc 'suggest', 'Suggest Ruby-Build tag for current Ruby version'
      long_desc <<~DESC
        Suggest an appropriate Ruby-Build tag based on the current Ruby version.

        This is useful when creating local environments to get the correct
        ruby_build_tag value.

        Examples:
          serialbench ruby-build suggest
      DESC
      def suggest
        current_ruby = RUBY_VERSION
        suggested_tag = RubyBuildManager.suggest_current_ruby_tag

        say "Current Ruby version: #{current_ruby}", :cyan
        say "Suggested ruby_build_tag: #{suggested_tag}", :green

        # Validate the suggestion
        if RubyBuildManager.validate_tag(suggested_tag)
          say '✅ Suggested tag is valid', :green
        else
          say '⚠️  Suggested tag not found in ruby-build definitions', :yellow
          say 'You may need to update the cache or use a different tag', :white
        end
      rescue StandardError => e
        say "❌ Failed to suggest tag: #{e.message}", :red
        say 'Try updating the cache: serialbench ruby-build update', :white
        exit 1
      end

      desc 'cache-info', 'Show information about the Ruby-Build definitions cache'
      long_desc <<~DESC
        Display information about the local Ruby-Build definitions cache,
        including location, age, and update status.

        Examples:
          serialbench ruby-build cache-info
      DESC
      def cache_info
        if RubyBuildManager.cache_exists?
          cache_age = RubyBuildManager.cache_age
          definitions_count = RubyBuildManager.list_definitions.length

          say 'Ruby-Build Cache Information:', :green
          say '=' * 40, :green
          say "Location: #{RubyBuildManager::CACHE_FILE}", :cyan
          say "Definitions: #{definitions_count}", :cyan
          say "Age: #{format_cache_age(cache_age)}", :cyan
          say 'Status: ✅ Available', :green

          if cache_age > 7 * 24 * 60 * 60 # 7 days
            say "\n💡 Cache is older than 7 days, consider updating:", :yellow
            say '  serialbench ruby-build update', :white
          end
        else
          say 'Ruby-Build Cache Information:', :green
          say '=' * 40, :green
          say "Location: #{RubyBuildManager::CACHE_FILE}", :cyan
          say 'Status: ❌ Not found', :red
          say "\n📥 Update the cache first:", :yellow
          say '  serialbench ruby-build update', :white
        end
      end

      private

      def format_cache_age(seconds)
        days = (seconds / (24 * 60 * 60)).to_i
        hours = ((seconds % (24 * 60 * 60)) / (60 * 60)).to_i

        if days.positive?
          "#{days} day#{'s' if days != 1}, #{hours} hour#{'s' if hours != 1}"
        elsif hours.positive?
          "#{hours} hour#{'s' if hours != 1}"
        else
          'less than 1 hour'
        end
      end
    end
  end
end
