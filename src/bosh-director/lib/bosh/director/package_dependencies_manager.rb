module Bosh
  module Director
    class PackageDependenciesManager
      def initialize(release_version)
        @release_version = release_version
      end

      def transitive_dependencies(package)
        dependency_set = Set.new
        visited = Set.new([package])
        pending = dependencies(package).to_a
        until pending.empty?
          dependency = pending.pop
          next unless visited.add?(dependency)

          dependency_set << dependency
          pending.concat(dependencies(dependency).to_a)
        end
        dependency_set
      end

      def dependencies(package)
        package.dependency_set.map { |package_name| @release_version.package_by_name(package_name) }.to_set
      end
    end
  end
end
