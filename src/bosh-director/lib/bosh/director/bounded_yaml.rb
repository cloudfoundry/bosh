require 'yaml'

module Bosh::Director
  module BoundedYaml
    MAX_DEPTH = 100
    MAX_EXPANDED_NODES = 1_000_000

    def self.load(...)
      validate!(YAML.load(...))
    end

    def self.safe_load(...)
      validate!(YAML.safe_load(...))
    end

    def self.load_file(...)
      validate!(YAML.load_file(...))
    end

    # Count the expanded tree while visiting each shared container only once.
    # Modest aliases remain supported, but cycles and excessive fan-out do not.
    def self.validate!(object)
      measure(object, {}, {}, 0)
      object
    end

    def self.measure(object, active, measured, depth)
      raise BadManifest, 'YAML nesting exceeds the supported depth' if depth > MAX_DEPTH
      return [1, 0] unless object.is_a?(Hash) || object.is_a?(Array)

      id = object.object_id
      raise BadManifest, 'YAML contains a cyclic alias' if active[id]
      if measured.key?(id)
        size, height = measured[id]
        raise BadManifest, 'YAML nesting exceeds the supported depth' if depth + height > MAX_DEPTH
        return [size, height]
      end

      active[id] = true
      size = 1
      height = 0
      children = object.is_a?(Hash) ? object.each_pair.flat_map { |key, value| [key, value] } : object
      children.each do |child|
        child_size, child_height = measure(child, active, measured, depth + 1)
        size += child_size
        height = [height, child_height + 1].max
        raise BadManifest, 'YAML alias expansion exceeds the supported size' if size > MAX_EXPANDED_NODES
      end
      active.delete(id)
      measured[id] = [size, height]
    end
    private_class_method :measure
  end
end
