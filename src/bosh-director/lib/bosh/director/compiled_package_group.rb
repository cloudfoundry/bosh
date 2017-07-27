module Bosh::Director
  class CompiledPackageGroup
    def initialize(release_version, stemcell)
      @release_version = release_version
      @stemcell = stemcell
    end

    def compiled_packages
      @compiled_packages ||= @release_version.templates.map do |job|
        job.package_names.map do |package_name|
          package = @release_version.package_by_name(package_name)
          package_dependency_key = KeyGenerator.new.dependency_key_from_models(package, @release_version)

          Models::CompiledPackage[
            :package_id => package.id,
            :stemcell_os => @stemcell.os,
            :stemcell_version => @stemcell.version,
            :dependency_key => package_dependency_key
          ]
        end.compact
      end.flatten.uniq
    end

    def stemcell_sha1
      @stemcell.sha1
    end

    attr_reader :release_version
  end
end
