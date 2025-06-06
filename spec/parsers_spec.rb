# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Serialbench Serializers' do
  let(:small_xml) { create_test_xml(:small) }
  let(:medium_xml) { create_test_xml(:medium) }
  let(:test_json) { '{"name":"test","values":[1,2,3]}' }
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
    describe Serialbench::Serializers::Xml::RexmlSerializer do
      let(:serializer) { Serialbench::Serializers::Xml::RexmlSerializer.new }

      it 'is available' do
        expect(serializer).to be_available
      end

      it 'has correct format' do
        expect(serializer.format).to eq(:xml)
      end

      it 'has a name and version' do
        expect(serializer.name).to eq('rexml')
        expect(serializer.version).to be_a(String)
      end

      it 'can parse XML' do
        result = serializer.parse(small_xml)
        expect(result).not_to be_nil
        expect(result).to respond_to(:root)
      end

      it 'can generate XML' do
        doc = serializer.parse(small_xml)
        xml_string = serializer.generate(doc)
        expect(xml_string).to be_a(String)
        expect(xml_string).to include('<?xml')
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
  end

  describe 'JSON Serializers' do
    describe Serialbench::Serializers::Json::JsonSerializer do
      let(:serializer) { Serialbench::Serializers::Json::JsonSerializer.new }

      it 'is available' do
        expect(serializer).to be_available
      end

      it 'has correct format' do
        expect(serializer.format).to eq(:json)
      end

      it 'has a name and version' do
        expect(serializer.name).to eq('json')
        expect(serializer.version).to be_a(String)
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
        expect(pretty_json).to include("\n")
        expect(pretty_json).to include("  ")
      end

      it 'does not support streaming' do
        expect(serializer.supports_streaming?).to be false
      end
    end

    describe Serialbench::Serializers::Json::OjSerializer do
      let(:serializer) { Serialbench::Serializers::Json::OjSerializer.new }

      context 'when Oj is available' do
        before do
          skip 'Oj not available' unless serializer.available?
        end

        it 'has correct format' do
          expect(serializer.format).to eq(:json)
        end

        it 'has a name and version' do
          expect(serializer.name).to eq('oj')
          expect(serializer.version).to be_a(String)
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

        it 'supports streaming' do
          expect(serializer.supports_streaming?).to be true
        end
      end

      context 'when Oj is not available' do
        before do
          allow(serializer).to receive(:require_library).with('oj').and_return(false)
        end

        it 'reports as unavailable' do
          expect(serializer).not_to be_available
        end
      end
    end
  end

  describe 'TOML Serializers' do
    describe Serialbench::Serializers::Toml::TomlRbSerializer do
      let(:serializer) { Serialbench::Serializers::Toml::TomlRbSerializer.new }

      context 'when TOML-RB is available' do
        before do
          skip 'TOML-RB not available' unless serializer.available?
        end

        it 'has correct format' do
          expect(serializer.format).to eq(:toml)
        end

        it 'has a name and version' do
          expect(serializer.name).to eq('toml-rb')
          expect(serializer.version).to be_a(String)
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

      context 'when TOML-RB is not available' do
        before do
          allow(serializer).to receive(:require_library).with('toml-rb').and_return(false)
        end

        it 'reports as unavailable' do
          expect(serializer).not_to be_available
        end
      end
    end
  end

  describe 'Serializer Registry' do
    describe Serialbench::Serializers do
      it 'returns all serializers' do
        all_serializers = Serialbench::Serializers.all
        expect(all_serializers).not_to be_empty
        expect(all_serializers).to all(be < Serialbench::Serializers::BaseSerializer)
      end

      it 'returns serializers for specific format' do
        xml_serializers = Serialbench::Serializers.for_format(:xml)
        expect(xml_serializers).not_to be_empty
        xml_serializers.each do |serializer_class|
          expect(serializer_class.new.format).to eq(:xml)
        end

        json_serializers = Serialbench::Serializers.for_format(:json)
        expect(json_serializers).not_to be_empty
        json_serializers.each do |serializer_class|
          expect(serializer_class.new.format).to eq(:json)
        end
      end

      it 'returns available serializers' do
        available_serializers = Serialbench::Serializers.available
        expect(available_serializers).not_to be_empty
        available_serializers.each do |serializer_class|
          expect(serializer_class.new).to be_available
        end
      end

      it 'returns available serializers for format' do
        available_xml = Serialbench::Serializers.available_for_format(:xml)
        expect(available_xml).not_to be_empty
        available_xml.each do |serializer_class|
          serializer = serializer_class.new
          expect(serializer.format).to eq(:xml)
          expect(serializer).to be_available
        end
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
end
