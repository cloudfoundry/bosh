module Bosh::Director::Models
  class Template < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :release
    many_to_many :release_versions

    def validate
      validates_presence [:release_id, :name, :version, :blobstore_id, :sha1]
      validates_unique [:release_id, :name, :version]
      validates_format VALID_ID, [:name, :version]
    end

    def package_names
      object_or_nil(self.package_names_json)
    end

    def package_names=(packages)
      self.package_names_json = json_encode(packages)
    end

    def logs=(logs_spec)
      self.logs_json = json_encode(logs_spec)
    end

    def logs
      object_or_nil(self.logs_json)
    end

    # @param [Object] property_spec Property spec from job spec
    def properties=(property_spec)
      self.properties_json = json_encode(property_spec)
    end

    # @return [Hash] Template properties (as provided in job spec)
    # @return [nil] if no properties have been defined in job spec
    def properties
      object_or_nil(self.properties_json)
    end

    def consumes=(consumes_spec)
      self.consumes_json = json_encode(consumes_spec)
    end

    def consumes
      object_or_nil(self.consumes_json)
    end

    def provides=(provides_spec)
      self.provides_json = json_encode(provides_spec)
    end

    def provides
      object_or_nil(self.provides_json)
    end

    private

    def object_or_nil(value)
      value ? Yajl::Parser.parse(value) : nil
    end

    def json_encode(value)
      Yajl::Encoder.encode(value)
    end
  end
end
