module Bosh
  module Director
    class KeyGenerator
      MAX_EXPANDED_DEPENDENCIES = 100_000
      MAX_DEPENDENCY_DEPTH = 100

      def dependency_key_from_models(package, release_version)
        prepare_packages(release_version.packages.map do |p|
          { 'name' => p.name, 'version' => p.version, 'dependencies' => p.dependency_set }
        end)
        PackageDependenciesManager.new(release_version).transitive_dependencies(package)
        package.dependency_set.sort.map { |name| arrayify(find_package_hash(name), Set.new, 0) }.to_json
      end

      def dependency_key_from_manifest(package_name, compiled_packages)
        prepare_packages(compiled_packages)
        package = find_package_hash(package_name)
        package['dependencies'].sort.map { |name| arrayify(find_package_hash(name), Set.new, 0) }.to_json
      end

      private

      def prepare_packages(packages)
        @packages_by_name = {}
        packages.each { |package| @packages_by_name[package['name']] ||= package }
        @expanded_dependencies = 0
      end

      def arrayify(package, active, depth)
        @expanded_dependencies += 1
        if depth > MAX_DEPENDENCY_DEPTH || @expanded_dependencies > MAX_EXPANDED_DEPENDENCIES
          raise ReleaseExistingPackageHashMismatch, 'Package dependency graph exceeds the supported size'
        end
        name = package['name']
        raise ReleaseExistingPackageHashMismatch, 'Package dependency graph contains a cycle' if active.include?(name)

        active.add(name)
        begin
          output = [name, package['version']]
          dependencies = package['dependencies']
          if dependencies && !dependencies.empty?
            output << dependencies.sort.map { |sub_dep| arrayify(find_package_hash(sub_dep), active, depth + 1) }
          end
          output
        ensure
          active.delete(name)
        end
      end

      def find_package_hash(name)
        @packages_by_name.fetch(name) do
          raise ReleaseExistingPackageHashMismatch, "Package '#{name}' not found in the release manifest."
        end
      end
    end
  end
end
