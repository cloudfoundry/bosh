module Bosh::Director
  class CompiledPackageGroup
    attr_reader :release_version

    def initialize(release_version, stemcell, jobs)
      @release_version = release_version
      @stemcell = stemcell
      @package_names = jobs.map(&:package_names).flatten.uniq
    end

    def compiled_packages
      @compiled_packages ||=
        begin
          packages_to_compile = @release_version.packages.select do |package|
            @package_names.include? package.name
          end

          packages_to_compile = resolve_dependencies(packages_to_compile)

          packages_to_compile.map do |package|
            package_dependency_key = KeyGenerator.new.dependency_key_from_models(package, @release_version)

            Models::CompiledPackage[
              package_id: package.id,
              stemcell_os: @stemcell.os,
              stemcell_version: @stemcell.version,
              dependency_key: package_dependency_key,
            ]
          end.compact
        end
    end

    def stemcell_sha1
      @stemcell.sha1
    end

    private

    def resolve_dependencies(packages)
      initial_count = packages.count
      new_list = (packages + packages.map do |package|
        @release_version.packages.select { |p| package.dependency_set.include?(p.name) }
      end).flatten.uniq

      if initial_count < new_list.count
        resolve_dependencies(new_list)
      else
        new_list
      end
    end
  end
end
