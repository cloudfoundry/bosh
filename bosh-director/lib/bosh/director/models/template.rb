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
      result = self.package_names_json
      result ? Yajl::Parser.parse(result) : nil
    end

    def package_names=(packages)
      self.package_names_json = Yajl::Encoder.encode(packages)
    end

    def logs=(logs_spec)
      self.logs_json = Yajl::Encoder.encode(logs_spec)
    end

    def logs
      result = self.logs_json
      result ? Yajl::Parser.parse(result) : nil
    end

    # @param [Object] property_spec Property spec from job spec
    def properties=(property_spec)
      self.properties_json = Yajl::Encoder.encode(property_spec)
    end

    # @return [Hash] Template properties (as provided in job spec)
    # @return [nil] if no properties have been defined in job spec
    def properties
      result = self.properties_json
      result ? Yajl::Parser.parse(result) : nil
    end
  end
end
