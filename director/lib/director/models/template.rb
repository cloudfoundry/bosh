module Bosh::Director::Models
  class Template < Sequel::Model
    many_to_one :release
    many_to_many :release_versions

    def package_names
      result = self.package_names_json
      result ? Yajl::Parser.parse(result) : nil
    end

    def package_names=(packages)
      self.package_names_json = Yajl::Encoder.encode(packages)
    end

    def validate
      validates_presence [:release_id, :name, :version, :blobstore_id, :sha1]
      validates_unique [:release_id, :name, :version]
      validates_format VALID_ID, [:name, :version]
    end
  end
end
