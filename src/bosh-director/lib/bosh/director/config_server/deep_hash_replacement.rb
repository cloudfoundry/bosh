require 'bosh/director/config_server/config_server_helper'

module Bosh::Director::ConfigServer
  class DeepHashReplacement
    include ConfigServerHelper

    def placeholders_paths(obj, subtrees_to_ignore = [])
      map = []
      construct_placeholders_paths(map, obj)

      result = map.select do |elem|
        !path_matches_subtrees_to_ignore?(subtrees_to_ignore, elem['path'])
      end

      result
    end

    def replace_placeholders(obj_to_be_resolved, placeholder_paths, placeholder_values)
      result = Bosh::Common::DeepCopy.copy(obj_to_be_resolved)
      errors = []

      placeholder_paths.each do |placeholder_path|
        config_path = placeholder_path['path']
        ret = result

        if config_path.length > 1
          ret = config_path[0..config_path.length-2].inject(result) do |obj, el|
            obj[el]
          end
        end

        placeholder = placeholder_path['placeholder']
        value_to_inject = placeholder_values[placeholder]
        target = ret[config_path.last]

        if target == placeholder
          ret[config_path.last] = value_to_inject
        else
          if value_to_inject.is_a?(String) || value_to_inject.is_a?(Fixnum)
            ret[config_path.last] = target.gsub(placeholder, value_to_inject.to_s)
          else
            errors <<  "- Failed to substitute placeholder: Can not replace '#{placeholder}' in '#{target}'. The value should be a String or an Integer."
          end
        end
      end

      if errors.length > 0
        message = errors.join("\n")
        raise Bosh::Director::ConfigServerIncorrectPlaceholderPlacement, message
      end

      result
    end

    private

    def construct_placeholders_paths(result, obj, path = nil)
      if obj.is_a? Array
        obj.each_with_index do |item, index|
          new_path = path.nil? ? [] : Bosh::Common::DeepCopy.copy(path)
          new_path << index
          construct_placeholders_paths(result, item, new_path)
        end
      elsif obj.is_a? Hash
        obj.each do |key, value|
          new_path = path.nil? ? [] : Bosh::Common::DeepCopy.copy(path)
          new_path << key
          construct_placeholders_paths(result, value, new_path)
        end
      else
        path ||= []
        placeholders = extract_placeholders_from_string(obj.to_s)
        placeholders.each do |placeholder|
          result << {'placeholder' => placeholder, 'path' => path}
        end
      end
    end

    def path_matches_subtrees_to_ignore?(subtrees_to_ignore, element_path)
      path_matches = false
      subtrees_to_ignore.each do |subtree_to_ignore|
        if paths_match?(subtree_to_ignore, element_path)
          path_matches = true
          break
        end
      end
      path_matches
    end

    def paths_match?(ignore_path, element_path)
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
