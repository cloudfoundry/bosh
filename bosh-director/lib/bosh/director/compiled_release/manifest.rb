module Bosh::Director
  module CompiledRelease
    class Manifest
      def initialize(manifest_hash)
        @manifest = manifest_hash
      end

      def has_matching_package(package_name, stemcell_os, stemcell_version, dependency_key)
        "#{stemcell_os}/#{stemcell_version}" == stemcell_os_and_version(package_name) &&
            dependency_key == dependency_key(package_name)
      end

      def dependency_key(package_name)
        compiled_package_meta_data = meta_data(package_name)
        dependencies = transitive_dependencies(compiled_package_meta_data, @manifest)

        key = dependencies.to_a.sort_by { |k| k["name"] }.map { |p| [p['name'], p['version']] }
        Yajl::Encoder.encode(key)
      end

      private

      def meta_data(package_name)
        @manifest['compiled_packages'].find { |p| p['name'] == package_name }
      end

      def stemcell_os_and_version(package_name)
        meta_data = meta_data(package_name)
        meta_data.nil? ? nil : meta_data['stemcell']
      end

      def transitive_dependencies(compiled_package_meta_data, manifest)
        dependencies = Set.new
        return dependencies if compiled_package_meta_data['dependencies'].nil?

        compiled_package_meta_data['dependencies'].each do |dependency_package_name|
          dependency_compiled_package_meta_data = meta_data(dependency_package_name)
          dependencies << dependency_compiled_package_meta_data
          dependencies.merge(transitive_dependencies(dependency_compiled_package_meta_data, manifest))
        end

        dependencies
      end
    end
  end
end
