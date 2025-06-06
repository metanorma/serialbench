source 'https://rubygems.org'

gemspec

group :development, :test do
  gem 'rake', '~> 13.0'
  gem 'rspec', '~> 3.12'
  gem 'rubocop', '~> 1.0'
end

group :benchmarking do
  gem 'csv', '~> 3.2' # Required from Ruby 3.4+

  # XML libraries
  gem 'libxml-ruby', '~> 4.0'
  gem 'nokogiri', '~> 1.15'
  gem 'oga', '~> 3.4'
  gem 'ox', '~> 2.14'
  gem 'rexml', '~> 3.2' # Required from Ruby 3.4+

  # JSON libraries
  gem 'json', '~> 2.6' # Built-in but explicit version
  gem 'oj', '~> 3.16'
  gem 'yajl-ruby', '~> 1.4'

  # TOML libraries
  gem 'tomlib', '~> 0.6'
  gem 'toml-rb', '~> 2.2'

  # Benchmarking and reporting tools
  gem 'asciidoctor', '~> 2.0'
  gem 'benchmark-ips', '~> 2.12'
  gem 'memory_profiler', '~> 1.0'
end
