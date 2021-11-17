module Bosh::Director
  module DeploymentPlan
    class CompiledPackageFinder
      def initialize(logger)
        @logger = logger
      end

      def find_compiled_package(package:, stemcell:, exported_from: [], dependency_key:, cache_key:, event_log_stage:)
        return find_exact_match_with_exported_from(package, exported_from, dependency_key) unless exported_from.empty?

        compiled_package = find_exact_match(package, stemcell, dependency_key)
        return compiled_package if compiled_package

        compiled_package = find_newest_match(package, stemcell, dependency_key) unless package.source?
        return compiled_package if compiled_package

      end

      private

      def find_exact_match_with_exported_from(package, exported_from, dependency_key)
        exported_from.each do |stemcell|
          result = find_exact_match(package, stemcell, dependency_key)
          return result if result
        end
      end

      def find_exact_match(package, stemcell, dependency_key)
        Models::CompiledPackage.find(
          package_id: package.id,
          stemcell_os: stemcell.os,
          stemcell_version: stemcell.version,
          dependency_key: dependency_key,
        )
      end

      def find_newest_match(package, stemcell, dependency_key)
        compiled_packages_for_stemcell_os = Models::CompiledPackage.where(
          package_id: package.id,
          stemcell_os: stemcell.os,
          dependency_key: dependency_key,
        ).all

        compiled_package_fuzzy_matches = compiled_packages_for_stemcell_os.select do |compiled_package_model|
          Bosh::Common::Version::StemcellVersion.match(compiled_package_model.stemcell_version, stemcell.version)
        end

        compiled_package_fuzzy_matches.max_by do |compiled_package_model|
          SemiSemantic::Version.parse(compiled_package_model.stemcell_version).release.components[1] || 0
        end
      end
    end
  end
end
