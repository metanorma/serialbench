# frozen_string_literal: true

require_relative 'lib/serialbench/version'

all_files_in_git = Dir.chdir(File.expand_path(__dir__)) do
  `git ls-files -z`.split("\x0")
end

Gem::Specification.new do |spec|
  spec.name = 'serialbench'
  spec.version = Serialbench::VERSION
  spec.authors = ['Ribose']
  spec.email = ['open.source@ribose.com']

  spec.summary = 'Comprehensive serialization benchmarking tool for Ruby'
  spec.description = 'A benchmarking suite for comparing performance of various serialization libraries in Ruby, including XML, JSON, and TOML parsers/generators.'
  spec.homepage = 'https://github.com/metanorma/serialbench'
  spec.license = 'BSD-2-Clause'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.7.0')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['bug_tracker_uri'] = "#{spec.homepage}/issues"

  # Specify which files should be added to the gem when it is released.
  spec.files = all_files_in_git
               .reject { |f| f.match(%r{\A(?:spec|features|bin|\.)/}) }

  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'benchmark-ips'
  spec.add_dependency 'memory_profiler'
  spec.add_dependency 'thor'

  # XML serializers
  spec.add_dependency 'libxml-ruby'
  spec.add_dependency 'nokogiri'
  spec.add_dependency 'oga'
  spec.add_dependency 'ox'

  # JSON serializers
  spec.add_dependency 'oj'
  spec.add_dependency 'yajl-ruby'

  # YAML serializers
  spec.add_dependency 'syck'

  # TOML serializers
  spec.add_dependency 'tomlib'
  spec.add_dependency 'toml-rb'
end
