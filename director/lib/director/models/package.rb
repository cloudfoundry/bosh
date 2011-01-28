module Bosh::Director::Models

  class Release < Ohm::Model; end
  class CompiledPackage < Ohm::Model; end

  class Package < Ohm::Model
    reference :release, Release
    attribute :name
    attribute :version
    attribute :blobstore_id
    attribute :sha1
    attribute :dependencies

    index :name
    index :version

    collection :compiled_packages, CompiledPackage

    def dependency_set
      result = self.dependencies
      ::Set.new(result ? Yajl::Parser.parse(result) : nil)
    end

    def dependency_set=(deps)
      self.dependencies = Yajl::Encoder.encode(deps.to_a)
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
