module Bosh::Director::Models
  class ReleaseVersion < Sequel::Model(Bosh::Director::Config.db)
    many_to_one  :release
    many_to_many :packages
    many_to_many :templates
    many_to_many :deployments

    def validate
      validates_presence [:release_id, :version]
      validates_unique [:release_id, :version]
      validates_format VALID_ID, :version
    end

    def dependencies(package_name)
      package_by_name(package_name).dependency_set.map do |package_name|
        package_by_name(package_name)
      end
    end

    def package_by_name(package_name)
      packages_by_name.fetch(package_name)
    end

    private

    def packages_by_name
      @packages_by_name ||= packages.inject({}) do |cache, package|
        cache.merge(package.name => package)
      end
    end
  end
end
