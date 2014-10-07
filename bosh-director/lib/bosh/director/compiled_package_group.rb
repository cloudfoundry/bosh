module Bosh::Director
  class CompiledPackageGroup
    def initialize(release_version, stemcell)
      @release_version = release_version
      @stemcell = stemcell
    end

    def compiled_packages
      @compiled_packages ||= @release_version.packages.map do |package|
        transitive_dependencies = @release_version.transitive_dependencies(package)
        package_dependency_key = Bosh::Director::Models::CompiledPackage.create_dependency_key(transitive_dependencies)
        Models::CompiledPackage[
          :package_id => package.id,
          :stemcell_id => @stemcell.id,
          :dependency_key => package_dependency_key
        ]
      end.compact
    end

    def stemcell_sha1
      @stemcell.sha1
    end

    attr_reader :release_version
  end
end
