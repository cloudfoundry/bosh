module Bosh::Director::Models
  class CompiledPackage < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :package
    many_to_one :stemcell

    def validate
      validates_presence [:package_id, :stemcell_id, :sha1, :blobstore_id, :dependency_key]
      validates_unique [:package_id, :stemcell_id, :dependency_key]
      validates_unique [:package_id, :stemcell_id, :build]
    end
  end
end
