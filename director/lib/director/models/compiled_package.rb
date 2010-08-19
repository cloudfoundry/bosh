module Bosh::Director::Models

  class Package < Ohm::Model; end
  class Stemcell < Ohm::Model; end

  class CompiledPackage < Ohm::Model
    reference :package, Package
    reference :stemcell, Stemcell
    attribute :sha1

    index :package
    index :stemcell

    def validate
      assert_present :package
      assert_present :stemcell
      assert_present :sha1

      assert_unique [:package_id, :stemcell_id]
    end
  end
end
