# frozen_string_literal: true

require_relative 'serializers/base_serializer'

# XML Serializers
require_relative 'serializers/xml/base_xml_serializer'
require_relative 'serializers/xml/rexml_serializer'
require_relative 'serializers/xml/ox_serializer'
require_relative 'serializers/xml/nokogiri_serializer'
require_relative 'serializers/xml/oga_serializer'
require_relative 'serializers/xml/libxml_serializer'

# JSON Serializers
require_relative 'serializers/json/base_json_serializer'
require_relative 'serializers/json/json_serializer'
require_relative 'serializers/json/oj_serializer'
require_relative 'serializers/json/yajl_serializer'
require_relative 'serializers/json/rapidjson_serializer'

# YAML Serializers
require_relative 'serializers/yaml/base_yaml_serializer'
require_relative 'serializers/yaml/psych_serializer'
require_relative 'serializers/yaml/syck_serializer'

# TOML Serializers
require_relative 'serializers/toml/base_toml_serializer'
require_relative 'serializers/toml/toml_rb_serializer'
require_relative 'serializers/toml/tomlib_serializer'

module Serialbench
  module Serializers
    # Registry of all available serializers
    SERIALIZERS = {
      xml: [
        Xml::RexmlSerializer,
        Xml::OxSerializer,
        Xml::NokogiriSerializer,
        Xml::OgaSerializer,
        Xml::LibxmlSerializer
      ],
      json: [
        Json::JsonSerializer,
        Json::OjSerializer,
        Json::RapidjsonSerializer,
        Json::YajlSerializer
      ],
      yaml: [
        Yaml::PsychSerializer,
        Yaml::SyckSerializer
      ],
      toml: [
        Toml::TomlRbSerializer,
        Toml::TomlibSerializer
      ]
    }.freeze

    def self.all
      SERIALIZERS.values.flatten
    end

    def self.for_format(format)
      SERIALIZERS[format.to_sym] || []
    end

    def self.available_for_format(format)
      for_format(format).select { |serializer_class| serializer_class.new.available? }
    end

    def self.available
      all.select { |serializer_class| serializer_class.new.available? }
    end
  end
end
