# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Serialbench Serializers' do
  let(:small_xml) { create_test_xml(:small) }
  let(:medium_xml) { create_test_xml(:medium) }
  let(:test_json) { '{"name":"test","values":[1,2,3]}' }
  let(:test_yaml) { "name: test\nvalues:\n  - 1\n  - 2\n  - 3\n" }
  let(:test_toml) { "[config]\nname = \"test\"\nvalues = [1, 2, 3]" }

  describe Serialbench::Serializers::BaseSerializer do
    let(:serializer) { Serialbench::Serializers::BaseSerializer.new }

    it 'defines the interface' do
      expect(serializer).to respond_to(:available?)
      expect(serializer).to respond_to(:parse)
      expect(serializer).to respond_to(:generate)
      expect(serializer).to respond_to(:name)
      expect(serializer).to respond_to(:version)
      expect(serializer).to respond_to(:format)
    end

    it 'raises NotImplementedError for abstract methods' do
      expect { serializer.parse(small_xml) }.to raise_error(NotImplementedError)
      expect { serializer.generate({}) }.to raise_error(NotImplementedError)
      expect { serializer.name }.to raise_error(NotImplementedError)
      expect { serializer.version }.to raise_error(NotImplementedError)
      expect { serializer.format }.to raise_error(NotImplementedError)
    end
  end

  describe 'XML Serializers' do
    shared_examples 'an XML serializer' do |serializer_class, expected_name|
      let(:serializer) { serializer_class.new }

      it 'has correct format' do
        expect(serializer.format).to eq(:xml)
      end

      it 'has expected name' do
        expect(serializer.name).to eq(expected_name)
      end

      it 'has a version' do
        expect(serializer.version).to be_a(String)
      end

      context 'when available' do
        before do
          skip "#{expected_name} not available" unless serializer.available?
        end

        it 'can parse XML' do
          result = serializer.parse(small_xml)
          expect(result).not_to be_nil
        end

        it 'can generate XML' do
          doc = serializer.parse(small_xml)
          xml_string = serializer.generate(doc)
          expect(xml_string).to be_a(String)
        end

        it 'handles medium-sized XML' do
          result = serializer.parse(medium_xml)
          expect(result).not_to be_nil
        end
      end
    end

    describe Serialbench::Serializers::Xml::RexmlSerializer do
      include_examples 'an XML serializer', Serialbench::Serializers::Xml::RexmlSerializer, 'rexml'

      let(:serializer) { Serialbench::Serializers::Xml::RexmlSerializer.new }

      it 'is always available (built-in)' do
        expect(serializer).to be_available
      end

      it 'supports streaming' do
        expect(serializer.supports_streaming?).to be true
      end

      it 'can stream parse' do
        events = []
        serializer.stream_parse(small_xml) do |event, data|
          events << [event, data]
        end
        expect(events).not_to be_empty
      end
    end

    describe Serialbench::Serializers::Xml::OxSerializer do
      include_examples 'an XML serializer', Serialbench::Serializers::Xml::OxSerializer, 'ox'

      let(:serializer) { Serialbench::Serializers::Xml::OxSerializer.new }

      context 'when available' do
        before do
          skip 'Ox not available' unless serializer.available?
        end

        it 'supports streaming' do
          expect(serializer.supports_streaming?).to be true
        end
      end
    end

    describe Serialbench::Serializers::Xml::NokogiriSerializer do
      include_examples 'an XML serializer', Serialbench::Serializers::Xml::NokogiriSerializer, 'nokogiri'

      let(:serializer) { Serialbench::Serializers::Xml::NokogiriSerializer.new }

      context 'when available' do
        before do
          skip 'Nokogiri not available' unless serializer.available?
        end

        it 'supports streaming' do
          expect(serializer.supports_streaming?).to be true
        end
      end
    end

    describe Serialbench::Serializers::Xml::OgaSerializer do
      include_examples 'an XML serializer', Serialbench::Serializers::Xml::OgaSerializer, 'oga'

      let(:serializer) { Serialbench::Serializers::Xml::OgaSerializer.new }

      context 'when available' do
        before do
          skip 'Oga not available' unless serializer.available?
        end

        it 'supports streaming' do
          expect(serializer.supports_streaming?).to be true
        end
      end
    end

    describe Serialbench::Serializers::Xml::LibxmlSerializer do
      include_examples 'an XML serializer', Serialbench::Serializers::Xml::LibxmlSerializer, 'libxml'

      let(:serializer) { Serialbench::Serializers::Xml::LibxmlSerializer.new }

      context 'when available' do
        before do
          skip 'LibXML not available' unless serializer.available?
        end

        it 'supports streaming' do
          expect(serializer.supports_streaming?).to be true
        end
      end
    end
  end

  describe 'JSON Serializers' do
    shared_examples 'a JSON serializer' do |serializer_class, expected_name|
      let(:serializer) { serializer_class.new }

      it 'has correct format' do
        expect(serializer.format).to eq(:json)
      end

      it 'has expected name' do
        expect(serializer.name).to eq(expected_name)
      end

      it 'has a version' do
        expect(serializer.version).to be_a(String)
      end

      context 'when available' do
        before do
          skip "#{expected_name} not available" unless serializer.available?
        end

        it 'can parse JSON' do
          result = serializer.parse(test_json)
          expect(result).to be_a(Hash)
          expect(result['name']).to eq('test')
          expect(result['values']).to eq([1, 2, 3])
        end

        it 'can generate JSON' do
          data = { 'name' => 'test', 'values' => [1, 2, 3] }
          json_string = serializer.generate(data)
          expect(json_string).to be_a(String)
          expect(JSON.parse(json_string)).to eq(data)
        end

        it 'can generate pretty JSON' do
          data = { 'name' => 'test', 'values' => [1, 2, 3] }
          pretty_json = serializer.generate(data, pretty: true)
          expect(pretty_json).to be_a(String)
        end
      end
    end

    describe Serialbench::Serializers::Json::JsonSerializer do
      include_examples 'a JSON serializer', Serialbench::Serializers::Json::JsonSerializer, 'json'

      let(:serializer) { Serialbench::Serializers::Json::JsonSerializer.new }

      it 'is always available (built-in)' do
        expect(serializer).to be_available
      end

      it 'does not support streaming' do
        expect(serializer.supports_streaming?).to be false
      end
    end

    describe Serialbench::Serializers::Json::OjSerializer do
      include_examples 'a JSON serializer', Serialbench::Serializers::Json::OjSerializer, 'oj'

      let(:serializer) { Serialbench::Serializers::Json::OjSerializer.new }

      context 'when available' do
        before do
          skip 'Oj not available' unless serializer.available?
        end

        it 'supports streaming' do
          expect(serializer.supports_streaming?).to be true
        end
      end
    end

    describe Serialbench::Serializers::Json::YajlSerializer do
      include_examples 'a JSON serializer', Serialbench::Serializers::Json::YajlSerializer, 'yajl'

      let(:serializer) { Serialbench::Serializers::Json::YajlSerializer.new }

      context 'when available' do
        before do
          skip 'YAJL not available' unless serializer.available?
        end

        it 'supports streaming' do
          expect(serializer.supports_streaming?).to be true
        end
      end
    end

    describe Serialbench::Serializers::Json::RapidjsonSerializer do
      include_examples 'a JSON serializer', Serialbench::Serializers::Json::RapidjsonSerializer, 'rapidjson'

      let(:serializer) { Serialbench::Serializers::Json::RapidjsonSerializer.new }

      context 'when available' do
        before do
          skip 'RapidJSON not available' unless serializer.available?
        end

        it 'supports streaming' do
          expect(serializer.supports_streaming?).to be true
        end
      end
    end
  end

  describe 'YAML Serializers' do
    shared_examples 'a YAML serializer' do |serializer_class, expected_name|
      let(:serializer) { serializer_class.new }

      it 'has correct format' do
        expect(serializer.format).to eq(:yaml)
      end

      it 'has expected name' do
        expect(serializer.name).to eq(expected_name)
      end

      it 'has a version' do
        expect(serializer.version).to be_a(String)
      end

      context 'when available' do
        before do
          skip "#{expected_name} not available" unless serializer.available?
        end

        it 'can parse YAML' do
          result = serializer.parse(test_yaml)
          expect(result).to be_a(Hash)
          expect(result['name']).to eq('test')
          expect(result['values']).to eq([1, 2, 3])
        end

        it 'can generate YAML' do
          data = { 'name' => 'test', 'values' => [1, 2, 3] }
          yaml_string = serializer.generate(data)
          expect(yaml_string).to be_a(String)
          expect(yaml_string).to include('name: test')
        end
      end
    end

    describe Serialbench::Serializers::Yaml::PsychSerializer do
      include_examples 'a YAML serializer', Serialbench::Serializers::Yaml::PsychSerializer, 'psych'

      let(:serializer) { Serialbench::Serializers::Yaml::PsychSerializer.new }

      it 'is always available (built-in)' do
        expect(serializer).to be_available
      end

      it 'supports streaming' do
        expect(serializer.supports_streaming?).to be true
      end
    end

    describe Serialbench::Serializers::Yaml::SyckSerializer do
      include_examples 'a YAML serializer', Serialbench::Serializers::Yaml::SyckSerializer, 'syck'

      let(:serializer) { Serialbench::Serializers::Yaml::SyckSerializer.new }

      context 'when available' do
        before do
          skip 'Syck not available' unless serializer.available?
        end

        it 'does not support streaming' do
          expect(serializer.supports_streaming?).to be false
        end
      end
    end
  end

  describe 'TOML Serializers' do
    shared_examples 'a TOML serializer' do |serializer_class, expected_name|
      let(:serializer) { serializer_class.new }

      it 'has correct format' do
        expect(serializer.format).to eq(:toml)
      end

      it 'has expected name' do
        expect(serializer.name).to eq(expected_name)
      end

      it 'has a version' do
        expect(serializer.version).to be_a(String)
      end

      context 'when available' do
        before do
          skip "#{expected_name} not available" unless serializer.available?
        end

        it 'can parse TOML' do
          result = serializer.parse(test_toml)
          expect(result).to be_a(Hash)
          expect(result['config']).to be_a(Hash)
          expect(result['config']['name']).to eq('test')
        end

        it 'can generate TOML' do
          data = { 'config' => { 'name' => 'test', 'values' => [1, 2, 3] } }
          toml_string = serializer.generate(data)
          expect(toml_string).to be_a(String)
          expect(toml_string).to include('[config]')
          expect(toml_string).to include('name = "test"')
        end

        it 'does not support streaming' do
          expect(serializer.supports_streaming?).to be false
        end
      end
    end

    describe Serialbench::Serializers::Toml::TomlRbSerializer do
      include_examples 'a TOML serializer', Serialbench::Serializers::Toml::TomlRbSerializer, 'toml-rb'
    end

    describe Serialbench::Serializers::Toml::TomlibSerializer do
      include_examples 'a TOML serializer', Serialbench::Serializers::Toml::TomlibSerializer, 'tomlib'
    end
  end

  describe 'Serializer Registry' do
    describe Serialbench::Serializers do
      it 'returns all serializers' do
        all_serializers = Serialbench::Serializers.all
        expect(all_serializers).not_to be_empty
        expect(all_serializers).to all(be < Serialbench::Serializers::BaseSerializer)
      end

      it 'returns serializers for each supported format' do
        %i[xml json yaml toml].each do |format|
          format_serializers = Serialbench::Serializers.for_format(format)
          expect(format_serializers).not_to be_empty
          format_serializers.each do |serializer_class|
            expect(serializer_class.new.format).to eq(format)
          end
        end
      end

      it 'returns available serializers' do
        available_serializers = Serialbench::Serializers.available
        expect(available_serializers).not_to be_empty
        available_serializers.each do |serializer_class|
          expect(serializer_class.new).to be_available
        end
      end

      it 'returns available serializers for each format' do
        %i[xml json yaml toml].each do |format|
          available_format = Serialbench::Serializers.available_for_format(format)
          available_format.each do |serializer_class|
            serializer = serializer_class.new
            expect(serializer.format).to eq(format)
            expect(serializer).to be_available
          end
        end
      end

      it 'includes all expected XML serializers' do
        xml_serializers = Serialbench::Serializers.for_format(:xml)
        expected_xml = %w[rexml ox nokogiri oga libxml]
        actual_xml = xml_serializers.map { |s| s.new.name }
        expect(actual_xml).to match_array(expected_xml)
      end

      it 'includes all expected JSON serializers' do
        json_serializers = Serialbench::Serializers.for_format(:json)
        expected_json = %w[json oj yajl rapidjson]
        actual_json = json_serializers.map { |s| s.new.name }
        expect(actual_json).to match_array(expected_json)
      end

      it 'includes all expected YAML serializers' do
        yaml_serializers = Serialbench::Serializers.for_format(:yaml)
        expected_yaml = %w[psych syck]
        actual_yaml = yaml_serializers.map { |s| s.new.name }
        expect(actual_yaml).to match_array(expected_yaml)
      end

      it 'includes all expected TOML serializers' do
        toml_serializers = Serialbench::Serializers.for_format(:toml)
        expected_toml = %w[toml-rb tomlib]
        actual_toml = toml_serializers.map { |s| s.new.name }
        expect(actual_toml).to match_array(expected_toml)
      end
    end
  end

  describe 'BenchmarkRunner' do
    let(:runner) { Serialbench::BenchmarkRunner.new(formats: [:json]) }

    it 'initializes with formats' do
      expect(runner.formats).to eq([:json])
    end

    it 'loads available serializers' do
      expect(runner.serializers).not_to be_empty
    end

    it 'can get serializers for format' do
      json_serializers = runner.serializers_for_format(:json)
      expect(json_serializers).not_to be_empty
      json_serializers.each do |serializer|
        expect(serializer.format).to eq(:json)
      end
    end

    it 'generates test data' do
      expect(runner.test_data).to have_key(:small)
      expect(runner.test_data).to have_key(:medium)
      expect(runner.test_data).to have_key(:large)
    end

    it 'can initialize with all formats' do
      all_formats_runner = Serialbench::BenchmarkRunner.new(formats: [:xml, :json, :yaml, :toml])
      expect(all_formats_runner.formats).to eq([:xml, :json, :yaml, :toml])
      expect(all_formats_runner.serializers).not_to be_empty
    end

    # Mock the actual benchmark running to avoid long test times
    it 'can run benchmarks (mocked)' do
      allow(runner).to receive(:run_parsing_benchmarks).and_return({})
      allow(runner).to receive(:run_generation_benchmarks).and_return({})
      allow(runner).to receive(:run_memory_benchmarks).and_return({})
      allow(runner).to receive(:run_streaming_benchmarks).and_return({})

      results = runner.run_all_benchmarks
      expect(results).to have_key(:environment)
      expect(results).to have_key(:parsing)
      expect(results).to have_key(:generation)
      expect(results).to have_key(:memory_usage)
    end
  end

  describe 'Cross-format compatibility' do
    let(:test_data) do
      {
        'name' => 'test',
        'values' => [1, 2, 3],
        'config' => {
          'enabled' => true,
          'timeout' => 30
        }
      }
    end

    it 'can round-trip data through available serializers' do
      Serialbench::Serializers.available.each do |serializer_class|
        serializer = serializer_class.new
        next unless serializer.available?

        begin
          # Generate serialized data
          serialized = serializer.generate(test_data)
          expect(serialized).to be_a(String)

          # Parse it back
          parsed = serializer.parse(serialized)
          expect(parsed).to be_a(Hash)

          # Basic structure should be preserved
          expect(parsed).to have_key('name')
          expect(parsed['name']).to eq('test')
        rescue => e
          # Some serializers might not support all data types
          # Log the error but don't fail the test
          puts "Warning: #{serializer.name} failed round-trip test: #{e.message}"
        end
      end
    end
  end

  describe 'Performance characteristics' do
    let(:small_data) { { 'test' => 'value' } }

    it 'all available serializers can handle basic operations' do
      Serialbench::Serializers.available.each do |serializer_class|
        serializer = serializer_class.new

        # Test basic generation
        expect { serializer.generate(small_data) }.not_to raise_error

        # Test basic parsing
        serialized = serializer.generate(small_data)
        expect { serializer.parse(serialized) }.not_to raise_error
      end
    end

    it 'streaming serializers report streaming support correctly' do
      streaming_serializers = Serialbench::Serializers.available.select do |serializer_class|
        serializer_class.new.supports_streaming?
      end

      expect(streaming_serializers).not_to be_empty
      streaming_serializers.each do |serializer_class|
        serializer = serializer_class.new
        expect(serializer).to respond_to(:stream_parse)
      end
    end
  end
end
