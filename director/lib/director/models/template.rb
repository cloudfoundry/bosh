module Bosh::Director::Models

  class Release < Ohm::Model; end
  class Package < Ohm::Model; end

  class Template < Ohm::Model
    reference :release_version, ReleaseVersion
    attribute :name
    attribute :blobstore_id
    set :packages, Package

    index :release_version
    index :name

    def validate
      assert_present :release_version
      assert_present :name
      assert_unique [:release_version_id, :name]
    end
  end
end
