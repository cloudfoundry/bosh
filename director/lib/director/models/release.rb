module Bosh::Director::Models

  class ReleaseVersion < Ohm::Model; end

  class Release < Ohm::Model
    attribute :name
    collection :versions, ReleaseVersion

    index :name

    def validate
      assert_present :name
      assert_unique [:name]
    end
  end
end
