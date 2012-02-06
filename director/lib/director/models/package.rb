module Bosh::Director::Models
  class Package < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :release
    many_to_many :release_versions
    one_to_many :compiled_packages

    def dependency_set
      result = self.dependency_set_json
      ::Set.new(result ? Yajl::Parser.parse(result) : nil)
    end

    def dependency_set=(deps)
      self.dependency_set_json = Yajl::Encoder.encode(deps.to_a)
    end

    def validate
      validates_presence [:release_id, :name, :version, :blobstore_id, :sha1]
      validates_unique [:release_id, :name, :version]
      validates_format VALID_ID, [:name, :version]
    end
  end
end
