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

    # immediate dependency models
    def dependencies(package)
      package.dependency_set.map { |package_name| package_by_name(package_name) }.to_set
    end

    # all dependency models, including transitives
    # assumes there are no cycles (checked during upload)
    def transitive_dependencies(package)
      dependency_set = Set.new
      dependencies(package).each do |dependency|
        dependency_set << dependency
        dependency_set.merge(transitive_dependencies(dependency))
      end
      dependency_set
    end

    def package_by_name(package_name)
      packages_by_name.fetch(package_name)
    end

    private

    def packages_by_name
      @packages_by_name_cache ||= packages.inject({}) do |cache, package|
        cache.merge(package.name => package)
      end
    end
  end
end
