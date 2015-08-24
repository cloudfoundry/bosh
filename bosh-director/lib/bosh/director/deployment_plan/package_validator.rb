module Bosh::Director
  module DeploymentPlan
    class PackageValidator
      def initialize
        @faults = {}
      end

      def validate(release_version_model, stemcel_model)
        release_version_model.packages.each do |package|
          packages_list = release_version_model.transitive_dependencies(package)
          packages_list << package

          release_desc = "#{release_version_model.release.name}/#{release_version_model.version}"

          packages_list.each do |needed_package|
            if needed_package.sha1.nil? || needed_package.blobstore_id.nil?
              compiled_packages_list = Bosh::Director::Models::CompiledPackage[:package_id => needed_package.id, :stemcell_id => stemcel_model.id]
              if compiled_packages_list.nil?
                @faults[release_desc] ||= []
                @faults[release_desc] << Fault.new(needed_package, stemcel_model)
              end
            end
          end
        end
      end

      def handle_faults
        return if @faults.empty?

        msg = "\n"
        unique_stemcells = @faults.group_by { |fault| fault.stemcell }

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
        msg += "Can't use release '#{release_desc}'. It references packages (see below) without source code and are not compiled against intended stemcells:\n"
        sorted_packages_and_stemcells = faults.sort_by { |fault| fault.package.name }
        sorted_packages_and_stemcells.each do |fault|
          msg += " - `#{fault.package_desc}' against `#{fault.stemcell.desc}'\n"
        end
      end

      def message_for_single_stemcell(release_desc, faults)
        sorted_faults = faults.to_a.sort_by { |fault| fault.package.name }
        stemcell_desc = faults.first.stemcell.desc

        msg = "Can't use release '#{release_desc}'. It references packages without" +
          " source code that are not compiled against '#{stemcell_desc}':\n"
        sorted_faults.each do |fault|
          msg += " - #{fault.package_desc}\n"
        end
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
