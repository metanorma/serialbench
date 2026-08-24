# frozen_string_literal: true

require 'open3'

RSpec.describe 'Leptris availability probe' do
  it 'reports unavailable instead of raising when the shared library cannot be loaded' do
    leptris_spec = Gem.loaded_specs['leptris']
    skip 'leptris gem not in this bundle' unless leptris_spec
    # The gem's ffi_lib list tries LEPTRIS_LIB_PATH first and falls through
    # to the vendored library when it fails, so with a precompiled platform
    # gem installed a bogus path never produces unavailability. The failure
    # path only reproduces with a pure-Ruby gem install; on CI it is covered
    # end-to-end by benchmark legs where the library cannot load at all.
    skip 'platform gem vendors its library; failure path not reproducible' if leptris_spec.platform != Gem::Platform::RUBY

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
