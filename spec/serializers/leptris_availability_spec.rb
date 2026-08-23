# frozen_string_literal: true

require 'open3'

RSpec.describe 'Leptris availability probe' do
  it 'reports unavailable instead of raising when the shared library cannot be loaded' do
    skip 'leptris gem not in this bundle' unless Gem::Specification.find_by_name('leptris')

    script = <<~RUBY
      require 'serialbench/serializers'
      print Serialbench::Serializers.for_format(:xml).select(&:available?).map(&:name).join(',')
    RUBY

    out, status = Open3.capture2({ 'LEPTRIS_LIB_PATH' => '/nonexistent/libleptris.so' },
                                 'bundle', 'exec', 'ruby', '-e', script)

    expect(status.success?).to be(true)
    expect(out.split(',')).not_to include('leptris')
  end
end
