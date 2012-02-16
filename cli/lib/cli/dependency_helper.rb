# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli
  module DependencyHelper

    # Expects package dependency graph
    # { "A" => ["B", "C"], "B" => ["C", "D"] }
    def tsort_packages(map)
      resolved = Set.new
      in_degree = { }
      graph = { }

      map.each_pair do |package, dependencies|
        graph[package] ||= Set.new
        in_degree[package] = dependencies.size

        resolved << package if in_degree[package] == 0

        # Reverse edges to avoid dfs
        dependencies.each do |dependency|
          unless map.has_key?(dependency)
            raise MissingDependency, ("Package '%s' depends on " +
                "missing package '%s'") % [ package, dependency ]
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

      # each_pair gives different (correct) results in 1.8 in 1.9,
      # stabilizing for tests
      graph.keys.sort.each do |v|
        e = graph[v]
        unless e.empty?
          raise CircularDependency, ("Cannot resolve dependencies for '%s': " +
              "circular dependency with '%s'") % [ v, e.first ]
        end
      end

      sorted
    end
  end

end

