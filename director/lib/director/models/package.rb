module Bosh::Director::Models

  class Release < Ohm::Model; end    

  class Package < Ohm::Model
    reference :release, Release
    attribute :name
    attribute :version
    attribute :sha1

    index :release
    index :name
    index :version

    def validate
      assert_present :release
      assert_present :name
      assert_present :version
      assert_present :sha1

      assert_unique [:release_id, :name, :version]
    end
  end
end
