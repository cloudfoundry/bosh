module Bosh::Director::Models

  class Deployment < Ohm::Model; end
  class ReleaseVersion < Ohm::Model; end

  class Release < Ohm::Model
    attribute :name
    collection :versions, ReleaseVersion
    collection :deployments, Deployment

    index :name

    def validate
      assert_present :name
      assert_unique [:name]
    end
  end
end
