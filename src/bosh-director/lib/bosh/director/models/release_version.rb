module Bosh::Director::Models
  class ReleaseVersion < Sequel::Model(Bosh::Director::Config.db)
    many_to_one  :release
    many_to_many :packages
    many_to_many :templates
    many_to_many :deployments

    def validate
      validates_format VALID_ID, :version
      validates_presence [:release_id, :version]
      validates_unique [:release_id, :version]
    end

    def package_by_name(package_name)
      packages_by_name.fetch(package_name) do
        raise "Package name '#{package_name}' not found in release '#{release.name}/#{version}'"
      end
    end

    private

    def packages_by_name
      @packages_by_name_cache ||= packages.inject({}) do |cache, package|
        cache.merge(package.name => package)
      end
    end
  end
end
