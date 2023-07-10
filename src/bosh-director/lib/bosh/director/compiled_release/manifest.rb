module Bosh::Director
  module CompiledRelease
    class Manifest
      def initialize(manifest_hash)
        @manifest = manifest_hash
      end

      def compiled_packages
        @manifest.fetch('compiled_packages', [])
      end

      def has_matching_package(package_name, stemcell_os, stemcell_version, dependency_key)
        "#{stemcell_os}/#{stemcell_version}" == stemcell_os_and_version(package_name) &&
          dependency_key == dependency_key(package_name)
      end

      def dependency_key(package_name)
        KeyGenerator.new.dependency_key_from_manifest(package_name, @manifest['compiled_packages'])
      end

      private

      def meta_data(package_name)
        compiled_packages.find { |p| p['name'] == package_name }
      end

      def stemcell_os_and_version(package_name)
        meta_data = meta_data(package_name)
        meta_data.nil? ? nil : meta_data['stemcell']
      end
    end
  end
end
