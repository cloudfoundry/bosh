module Bosh
  module Director
    class PackageDependenciesManager
      def initialize(release_version)
        @release_version = release_version
      end

      def transitive_dependencies(package)
        dependency_set = Set.new
        dependencies(package).each do |dependency|
          dependency_set << dependency
          dependency_set.merge(transitive_dependencies(dependency))
        end
        dependency_set
      end

      def dependencies(package)
        package.dependency_set.map { |package_name| @release_version.package_by_name(package_name) }.to_set
      end
    end
  end
end
