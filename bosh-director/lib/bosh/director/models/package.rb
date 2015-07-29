# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director::Models
  class Package < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :release
    many_to_many :release_versions
    one_to_many :compiled_packages

    # @return [Set<String>] A set of package names this package depends on
    def dependency_set
      json = self.dependency_set_json

      ::Set.new(json ? Yajl::Parser.parse(json) : nil)
    end

    def dependency_set=(deps)
      self.dependency_set_json = Yajl::Encoder.encode(deps.to_a)
    end

    def validate
      if !sha1.nil? || !blobstore_id.nil?
        validates_presence [:sha1, :blobstore_id]
      end

      validates_presence [:release_id, :name, :version]
      validates_unique [:release_id, :name, :version]
      validates_format VALID_ID, [:name, :version]
    end

    def desc
      "#{name}/#{version}"
    end
  end
end
