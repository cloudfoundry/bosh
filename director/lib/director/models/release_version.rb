module Bosh::Director::Models

  class ReleaseVersion < Ohm::Model
    reference :release, Release
    attribute :version

    index :release
    index :version

    def validate
      assert_present :version

      assert_unique [:release_id, :version]
    end
  end
end
