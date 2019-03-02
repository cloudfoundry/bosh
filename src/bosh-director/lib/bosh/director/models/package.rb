module Bosh::Director::Models
  class Package < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :release
    many_to_many :release_versions
    one_to_many :compiled_packages

    # @return [Set<String>] A set of package names this package depends on
    def dependency_set
      json = dependency_set_json

      ::Set.new(json ? JSON.parse(json) : nil)
    end

    def dependency_set=(deps)
      self.dependency_set_json = JSON.generate(deps.to_a)
    end

    def validate
      validates_presence %i[sha1 blobstore_id] if !sha1.nil? || !blobstore_id.nil?

      validates_presence %i[release_id name version]
      validates_unique %i[release_id name version]
      validates_format VALID_ID, %i[name version]
    end

    def desc
      "#{name}/#{version}"
    end

    def source?
      !sha1.nil? || !blobstore_id.nil?
    end
  end
end
