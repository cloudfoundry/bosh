module Bosh::Cli

  module DependencyHelper

    # Expects package dependency graph
    # { "A" => ["B", "C"], "B" => ["C", "D"] }
    def tsort_packages(map)
      resolved = Set.new
      in_degree = { }
      graph     = { }

      map.each_pair do |package, dependencies|
        graph[package]     ||= Set.new
        in_degree[package]   = dependencies.size

        resolved << package if in_degree[package] == 0

        # Reverse edges to avoid dfs
        dependencies.each do |dependency|
          unless map.has_key?(dependency)
            raise MissingDependency, "Package '%s' depends on missing package '%s'" % [ package, dependency ]
          end

          graph[dependency] ||= Set.new
          graph[dependency] << package
        end
      end

      sorted = [ ]

      until resolved.empty?
        p = resolved.first
        resolved.delete(p)

        sorted << p

        graph[p].each do |v|
          in_degree[v] -= 1
          resolved << v if in_degree[v] == 0
        end
        graph[p].clear
      end

      graph.each_pair do |v, e|
        raise CircularDependency, "Cannot resolve dependencies for '#{v}': circular dependency with '#{e.first}'" unless e.empty?
      end

      sorted
    end
  end
  
end

