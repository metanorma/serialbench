# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

# Platform-specific dependencies
# libxml-ruby fails to compile on Windows ARM, but works on other platforms
unless Gem.win_platform? && RUBY_PLATFORM.include?('aarch64')
  gem 'libxml-ruby'
end

gem 'base64'  # Required for Ruby 3.4+
gem 'lutaml-model', '~> 0.7'
gem 'octokit'
gem 'rake'
gem 'rspec'
gem 'rubocop'
gem 'rubocop-performance'
gem 'rubocop-rspec'
