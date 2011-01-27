module Bosh::Director::Models

  class Release < Ohm::Model; end
  class Package < Ohm::Model; end

  class Template < Ohm::Model
    reference :release, Release
    attribute :name
    attribute :version
    attribute :blobstore_id
    attribute :sha1
    attribute :package_names

    index :name
    index :version

    def packages
      result = self.package_names
      result ? Yajl::Parser.parse(result) : nil
    end

    def packages=(packages)
      self.package_names = Yajl::Encoder.encode(packages)
    end

    def validate
      assert_present :release_id
      assert_present :name
      assert_present :version
      assert_present :sha1
      assert_unique [:release_id, :name, :version]
    end
  end
end
