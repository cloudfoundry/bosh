require 'bosh/director/models/compiled_package'

module Bosh::Director
  class CompiledPackageGroup
    def initialize(release_version, stemcell)
      @release_version = release_version
      @stemcell = stemcell
    end

    def compiled_packages
      @release_version.packages.map do |package|
        Models::CompiledPackage[
          :package_id => package.id,
          :stemcell_id => @stemcell.id,
          :dependency_key => @release_version.package_dependency_key(package.name)
        ]
      end.compact
    end

    def stemcell_sha1
      @stemcell.sha1
    end
  end
end
