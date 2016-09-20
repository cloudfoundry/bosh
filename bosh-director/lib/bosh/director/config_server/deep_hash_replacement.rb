require 'net/http'

module Bosh::Director::ConfigServer
  class DeepHashReplacement
    def self.replacement_map(obj, subtrees_to_ignore = [])
      map = []
      create_replacement_map(map, obj)

      result = map.select do |elem|
        !path_matches_subtrees_to_ignore?(subtrees_to_ignore, elem['path'])
      end

      result
    end

    private

    def self.create_replacement_map(result, obj, path = nil)
      if obj.is_a? Array
        obj.each_with_index do |item, index|
          new_path = path.nil? ? [] : Bosh::Common::DeepCopy.copy(path)
          new_path << index
          create_replacement_map(result, item, new_path)
        end
      elsif obj.is_a? Hash
        obj.each do |key, value|
          new_path = path.nil? ? [] : Bosh::Common::DeepCopy.copy(path)
          new_path << key
          create_replacement_map(result, value, new_path)
        end
      else
        path ||= []
        if obj.to_s.match(/^\(\(.*\)\)$/)
          key_name = obj.gsub(/(^\(\(|\)\)$)/, '')
          result << {'key' => key_name, 'path' => path}
        end
      end
    end

    def self.path_matches_subtrees_to_ignore?(subtrees_to_ignore, element_path)
      path_matches = false
      subtrees_to_ignore.each do |subtree_to_ignore|
        if self.paths_match?(subtree_to_ignore, element_path)
          path_matches = true
          break
        end
      end
      path_matches
    end

    def self.paths_match?(ignore_path, element_path)
      paths_match = true
      if ignore_path.size <= element_path.size
        ignore_path.each_with_index do | ignored_node, index |
          element_node = element_path[index]
          if ignored_node.is_a?(Class)
            (paths_match = false) unless element_node.is_a?(ignored_node)
          else
            (paths_match = false) unless element_node == ignored_node
          end
        end
      else
        paths_match = false
      end
      paths_match
    end
  end
end
