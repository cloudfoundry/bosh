module Bosh::Director
  module DeploymentPlan
    class PackageValidator
      def initialize(logger)
        @faults = {}
        @logger = logger
      end

      def validate(release_version_model, stemcell, job_packages, exported_from)
        release_desc = "#{release_version_model.release.name}/#{release_version_model.version}"

        @logger.debug("Validating packages for release '#{release_desc}'")
        filtered_job_packages = release_version_model.packages.select { |p| job_packages.include?(p.name) }
        filtered_job_packages.each do |package|
          packages_list = Bosh::Director::PackageDependenciesManager.new(release_version_model).transitive_dependencies(package)
          packages_list << package
          packages_list.each do |needed_package|
            if needs_exact_compiled_package?(exported_from)
              filtered_exported_from = exported_from.select { |e| e.compatible_with?(stemcell) }

              if filtered_exported_from.empty?
                add_fault(
                  release_desc,
                  needed_package,
                  stemcell,
                  StemcellNotPresentInExportedFrom,
                )
              end

              validate_exact_compiled_package(needed_package, filtered_exported_from, release_desc)
              next
            end

            next if needed_package.source?

            compiled_packages_list = Bosh::Director::Models::CompiledPackage.where(
              package_id: needed_package.id,
              stemcell_os: stemcell.os,
            ).all

            compiled_packages_list = compiled_packages_list.select do |compiled_package|
              Bosh::Version::StemcellVersion.match(compiled_package.stemcell_version, stemcell.version)
            end

            add_fault(release_desc, needed_package, stemcell) if compiled_packages_list.empty?
          end
        end
      end

      def handle_faults
        return if @faults.empty?

        msg = "\n"
        unique_stemcells = @faults.map { |_, faults| faults.map { |fault| fault[:stemcell] } }.flatten.to_set

        exception = PackageMissingSourceCode

        @faults.each do |release_desc, faults|
          exception = faults.first[:exception]

          if exception == PackageMissingExportedFrom
            msg += message_for_exported_from(release_desc, faults)
            next
          end

          if exception == StemcellNotPresentInExportedFrom
            msg += message_for_exported_from_stemcell_mismatch(release_desc, faults)
            next
          end

          msg += if unique_stemcells.size > 1
                   message_for_multiple_stemcells(release_desc, faults)
                 else
                   message_for_single_stemcell(release_desc, faults)
                 end
        end

        raise exception, msg
      end

      private

      def validate_exact_compiled_package(package, stemcells, release_desc)
        stemcells.each do |stemcell|
          return true if exact_compiled_package?(package, stemcell)
        end

        stemcells.each do |s|
          add_fault(release_desc, package, s, PackageMissingExportedFrom)
        end
      end

      def message_for_multiple_stemcells(release_desc, faults)
        msg = "Can't use release '#{release_desc}'. It references packages without" \
              " source code and are not compiled against intended stemcells:\n"
        sorted_faults = faults.to_a.sort_by { |fault| fault[:package].name }
        sorted_faults.each do |fault|
          msg += " - '#{fault[:package].desc}' against stemcell '#{fault[:stemcell].desc}'\n"
        end

        msg
      end

      def message_for_single_stemcell(release_desc, faults)
        stemcell_desc = faults.first[:stemcell].desc

        msg = "Can't use release '#{release_desc}'. It references packages without" \
              " source code and are not compiled against stemcell '#{stemcell_desc}':\n"

        msg + listed_packages(faults)
      end

      def message_for_exported_from(release_desc, faults)
        msg = "Can't use release '#{release_desc}':\n"

        faults.group_by { |fault| fault[:stemcell] }.each do |stemcell, stemcell_faults|
          exported_from_desc = "#{stemcell.os}/#{stemcell.version}"

          msg += "Packages must be exported from stemcell '#{exported_from_desc}', but some packages are not "\
                 "compiled for this stemcell:\n"
          msg += listed_packages(stemcell_faults)
        end
        msg
      end

      def message_for_exported_from_stemcell_mismatch(release_desc, faults)
        stemcells = faults.group_by { |fault| fault[:stemcell] }.map { |s| "#{s[0].os}/#{s[0].version}" }

        "Can't use release '#{release_desc}': expected to find stemcell for '#{stemcells.join("', '")}' "\
        "to be configured in exported_from'"
      end

      def listed_packages(faults)
        sorted_faults = faults.to_a.sort_by { |fault| fault[:package].name }
        sorted_faults.map { |fault| " - '#{fault[:package].desc}'\n" }.join('')
      end

      def needs_exact_compiled_package?(exported_from)
        !exported_from.empty?
      end

      def exact_compiled_package?(package, stemcell)
        Bosh::Director::Models::CompiledPackage.find(
          package_id: package.id,
          stemcell_os: stemcell.os,
          stemcell_version: stemcell.version,
        )
      end

      def add_fault(release, package, stemcell, exception = PackageMissingSourceCode)
        @faults[release] ||= Set.new
        @faults[release] << { package: package, stemcell: stemcell, exception: exception }
      end
    end
  end
end
