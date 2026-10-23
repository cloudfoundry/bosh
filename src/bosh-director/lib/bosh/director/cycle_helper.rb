module Bosh::Director::CycleHelper
  def self.check_for_cycle(vertices, options = {}, &block)
    result = {}
    result[:connected_vertices] = {} if options[:connected_vertices]
    valid_vertices = vertices.to_set
    checked = Set.new
    vertices.each do |vertex|
      visited = options[:connected_vertices] ? Set.new : checked
      connected = options[:connected_vertices] ? Set.new : nil
      walk_graph(vertex, valid_vertices, visited, connected, &block)
      result[:connected_vertices][vertex] = connected.to_a if connected
    end
    result
  end

  def self.walk_graph(root, valid_vertices, visited, connected)
    path = {}
    stack = [[root, false]]
    until stack.empty?
      vertex, leaving = stack.pop
      if leaving
        path.delete(vertex)
        visited.add(vertex)
        next
      end
      raise "Invalid edge: #{vertex}" unless valid_vertices.include?(vertex)
      raise "Cycle: #{(path.keys + [vertex]).join('=>')}" if path.key?(vertex)
      connected.add(vertex) if connected && vertex != root
      next if visited.include?(vertex)

      path[vertex] = true
      stack << [vertex, true]
      Array(yield(vertex)).reverse_each { |edge| stack << [edge, false] }
    end
  end
  private_class_method :walk_graph
end
