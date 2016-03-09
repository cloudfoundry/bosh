module Bosh::Director
  module DeploymentPlan
    class PackageValidator
      def initialize(logger)
        @faults = {}
        @logger = logger
      end

      def validate(release_version_model, stemcell_model)
        release_desc = "#{release_version_model.release.name}/#{release_version_model.version}"

        @logger.debug("Validating packages for release '#{release_desc}'")
        release_version_model.packages.each do |package|
          packages_list = Bosh::Director::PackageDependenciesManager.new(release_version_model).transitive_dependencies(package)
          packages_list << package
          packages_list.each do |needed_package|
            if needed_package.sha1.nil? || needed_package.blobstore_id.nil?
              compiled_packages_list = Bosh::Director::Models::CompiledPackage.where(:package_id => needed_package.id,
                :stemcell_os => stemcell_model.operating_system).all
              compiled_packages_list = compiled_packages_list.select do |compiled_package|
                Bosh::Common::Version::StemcellVersion.match(compiled_package.stemcell_version, stemcell_model.version)
              end
              if compiled_packages_list.empty?
                @faults[release_desc] ||= Set.new
                @faults[release_desc] << Fault.new(needed_package, stemcell_model)
              end
            end
          end
        end
      end

      def handle_faults
        return if @faults.empty?

        msg = "\n"
        unique_stemcells = @faults.map { |_, faults| faults.map { |fault| fault.stemcell } }.flatten.to_set

        @faults.each do |release_desc, faults|
          if unique_stemcells.size > 1
            msg += message_for_multiple_stemcells(release_desc, faults)
          else
            msg += message_for_single_stemcell(release_desc, faults)
          end
        end

        raise PackageMissingSourceCode, msg
      end

      private

      def message_for_multiple_stemcells(release_desc, faults)
        msg = "Can't use release '#{release_desc}'. It references packages without source code and are not compiled against intended stemcells:\n"
        sorted_faults = faults.to_a.sort_by { |fault| fault.package.name }
        sorted_faults.each do |fault|
          msg += " - '#{fault.package_desc}' against stemcell '#{fault.stemcell.desc}'\n"
        end

        msg
      end

      def message_for_single_stemcell(release_desc, faults)
        sorted_faults = faults.to_a.sort_by { |fault| fault.package.name }
        stemcell_desc = faults.first.stemcell.desc

        msg = "Can't use release '#{release_desc}'. It references packages without" +
          " source code and are not compiled against stemcell '#{stemcell_desc}':\n"
        sorted_faults.each do |fault|
          msg += " - '#{fault.package_desc}'\n"
        end

        msg
      end

      private

      class Fault < Struct.new(:package, :stemcell)
        def package_desc
          "#{package.name}/#{package.version}"
        end
      end
    end
  end
end
