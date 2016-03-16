module Bosh::Director
  class CompiledPackageGroup
    def initialize(release_version, stemcell)
      @release_version = release_version
      @stemcell = stemcell
    end

    def compiled_packages
      @compiled_packages ||= @release_version.packages.map do |package|
        package_dependency_key = KeyGenerator.new.dependency_key_from_models(package, @release_version)

        Models::CompiledPackage[
          :package_id => package.id,
          :stemcell_os => @stemcell.operating_system,
          :stemcell_version => @stemcell.version,
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
