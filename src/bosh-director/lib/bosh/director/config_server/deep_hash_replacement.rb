require 'bosh/director/config_server/config_server_helper'

module Bosh::Director::ConfigServer
  class DeepHashReplacement

    def variables_path(obj, subtrees_to_ignore = [])
      map = []
      construct_variables_paths(map, obj)

      map.select do |elem|
        !path_matches_subtrees_to_ignore?(subtrees_to_ignore, elem['path'])
      end
    end

    def replace_variables(obj_to_be_resolved, variables_paths, variable_values)
      result = Bosh::Director::DeepCopy.copy(obj_to_be_resolved)
      errors = []

      variables_paths.each do |variables_path|
        config_path = variables_path['path']
        variable_values_copy = Bosh::Director::DeepCopy.copy(variable_values)

        ret = result

        if config_path.length > 1
          ret = config_path[0..config_path.length-2].inject(result) do |obj, el|
            obj[el]
          end
        end

        variable_list = variables_path['variables']
        target_to_replace = ret[config_path.last]

        if variables_path['is_key']
          uninterpolated_key = variable_list.first
          interpolated_key = variable_values_copy[uninterpolated_key]
          if config_path.length >= 1
             ret[config_path.last][interpolated_key] = ret[config_path.last].delete(uninterpolated_key)
          else
            ret[interpolated_key] = ret.delete(uninterpolated_key)
          end
          next
        end

        if variable_list.size == 1 && variable_list.first == target_to_replace
          ret[config_path.last] = variable_values_copy[variable_list.first]
        else
          current_errors = []

          variable_list.each do |variable|
            variable_value = variable_values_copy[variable]
            unless variable_value.is_a?(String) || variable_value.is_a?(Integer)
              current_errors <<  "- Failed to substitute variable: Can not replace '#{variable}' in '#{target_to_replace}'. The value should be a String or an Integer."
            end
          end

          if current_errors.empty?
            replacement_regex = Regexp.new(variable_values_copy.keys.map { |x| Regexp.escape(x) }.join('|'))
            needed_variables = variable_values_copy.select { |key, _| variable_list.include? key }
            ret[config_path.last] = target_to_replace.gsub(replacement_regex, needed_variables)
          else
            errors << current_errors
          end
        end
      end

      if errors.length > 0
        message = errors.join("\n")
        raise Bosh::Director::ConfigServerIncorrectVariablePlacement, message
      end

      result
    end

    private

    def construct_variables_paths(result, obj, path=nil, is_key=false)
      if obj.is_a? Array
        obj.each_with_index do |item, index|
          new_path = path.nil? ? [] : Bosh::Director::DeepCopy.copy(path)
          construct_variables_paths(result, item, new_path + [index])
        end
      elsif obj.is_a? Hash
        obj.each do |key, value|
          new_path = path.nil? ? [] : Bosh::Director::DeepCopy.copy(path)
          construct_variables_paths(result, value, new_path + [key])
          construct_variables_paths(result, key, new_path, true) if ConfigServerHelper.is_full_variable?(key)
        end
      else
        path ||= []
        variables = ConfigServerHelper.extract_variables_from_string(obj.to_s)
        result << { 'variables' => variables, 'path' => path, 'is_key' => is_key } unless variables.empty?
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
