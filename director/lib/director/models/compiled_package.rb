# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director::Models
  class CompiledPackage < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :package
    many_to_one :stemcell

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

    def self.generate_build_number(package, stemcell)
      attrs = {
        :package_id => package.id,
        :stemcell_id => stemcell.id
      }

      filter(attrs).max(:build).to_i + 1
    end

  end
end
