module Bosh::Director::Models

  class Package < Ohm::Model; end
  class Stemcell < Ohm::Model; end

  class CompiledPackage < Ohm::Model
    reference :package, Package
    reference :stemcell, Stemcell
    attribute :blobstore_id
    attribute :sha1
    attribute :dependency_key

    index :dependency_key

    def validate
      assert_present :package_id
      assert_present :stemcell_id
      assert_present :sha1
      assert_unique [:package_id, :stemcell_id, :dependency_key]
    end
  end
end
