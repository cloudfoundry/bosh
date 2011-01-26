module Bosh::Director::Models

  class Release < Ohm::Model; end
  class Package < Ohm::Model; end
  class Template < Ohm::Model; end

  class ReleaseVersion < Ohm::Model
    reference :release, Release
    attribute :version
    set :packages, Package
    set :templates, Template

    index :version

    def validate
      assert_present :version
      assert_unique [:release_id, :version]
    end
  end
end
