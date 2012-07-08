# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director::Models
  class CompiledPackage < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :package
    many_to_one :stemcell

    # Generates stable dependency key for compiled package
    # @param [Array<Bosh::Director::Models::Package>]
    # @return [String] Dependency key
    def self.generate_dependency_key(packages)
      key = packages.sort { |a, b|
        a.name <=> b.name
      }.map { |p| [p.name, p.version]}

      Yajl::Encoder.encode(key)
    end

    def validate
      validates_presence [:package_id, :stemcell_id, :sha1,
                          :blobstore_id, :dependency_key]
      validates_unique [:package_id, :stemcell_id, :dependency_key]
      validates_unique [:package_id, :stemcell_id, :build]
    end

    def name
      package.name
    end

    def version
      package.version
    end

  end
end
