module Bosh::Director::CycleHelper

  def self.check_for_cycle(vertices, options = {}, &block)
    result = {}
    result[:connected_vertices] = {} if options[:connected_vertices]
    vertices.each do |vertex|
      path = {}
      connected_vertices = options[:connected_vertices] ? Set.new : nil
      check_for_cycle_helper(path, vertices, vertex, connected_vertices, &block)
      result[:connected_vertices][vertex] = connected_vertices.to_a if connected_vertices
    end
    result
  end

  def self.check_for_cycle_helper(path, valid_vertices, vertex, connected_vertices, &block)
    path[vertex] = path.size + 1
    connected_vertices << vertex if connected_vertices && path.size > 1
    edges = block.call(vertex)
    if edges
      edges.each do |edge|
        raise "Invalid edge: #{edge}" unless valid_vertices.include?(edge)
        if path.include?(edge)
          vertex_path = []
          path = path.invert
          path.size.times { |index| vertex_path << path[index + 1] }
          raise "Cycle: #{vertex_path.join("=>")}=>#{edge}"
        end
        check_for_cycle_helper(path, valid_vertices, edge, connected_vertices, &block)
      end
    end
    path.delete(vertex)
  end

end