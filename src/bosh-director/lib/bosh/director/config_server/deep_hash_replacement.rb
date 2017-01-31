require 'bosh/director/config_server/config_server_helper'

module Bosh::Director::ConfigServer
  class DeepHashReplacement

    def placeholders_paths(obj, subtrees_to_ignore = [])
      map = []
      construct_placeholders_paths(map, obj)

      result = map.select do |elem|
        !path_matches_subtrees_to_ignore?(subtrees_to_ignore, elem['path'])
      end

      result
    end

    def replace_placeholders(obj_to_be_resolved, placeholders_paths, placeholder_values)
      result = Bosh::Common::DeepCopy.copy(obj_to_be_resolved)
      errors = []

      placeholders_paths.each do |placeholders_path|
        config_path = placeholders_path['path']
        placeholder_values_copy = Bosh::Common::DeepCopy.copy(placeholder_values)

        ret = result

        if config_path.length > 1
          ret = config_path[0..config_path.length-2].inject(result) do |obj, el|
            obj[el]
          end
        end

        placeholders_list = placeholders_path['placeholders']
        target_to_replace = ret[config_path.last]

        if placeholders_list.size == 1 && placeholders_list.first == target_to_replace
          ret[config_path.last] = placeholder_values_copy[placeholders_list.first]
        else
          current_errors = []

          placeholders_list.each do |placeholder|
            placeholder_value = placeholder_values_copy[placeholder]
            unless placeholder_value.is_a?(String) || placeholder_value.is_a?(Fixnum)
              current_errors <<  "- Failed to substitute placeholder: Can not replace '#{placeholder}' in '#{target_to_replace}'. The value should be a String or an Integer."
            end
          end

          if current_errors.empty?
            replacement_regex = Regexp.new(placeholder_values_copy.keys.map { |x| Regexp.escape(x) }.join('|'))
            needed_placeholders = placeholder_values_copy.select { |key, _| placeholders_list.include? key }
            ret[config_path.last] = target_to_replace.gsub(replacement_regex, needed_placeholders)
          else
            errors << current_errors
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
        placeholders = ConfigServerHelper.extract_placeholders_from_string(obj.to_s)
        result << {'placeholders' => placeholders, 'path' => path} unless placeholders.empty?
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
