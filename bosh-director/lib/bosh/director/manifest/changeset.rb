class ::Hash
  def deep_merge(second)
    merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
    self.merge(second, &merger)
  end
end

module Bosh::Director
  class Changeset
    KEY_NAME = 'name'

    def initialize(before, after)
      @before = before
      @after = after
      if @before && @after
        @merged = @before.deep_merge(@after)
      elsif @before
        @merged = @before
      else
        @merged = @after
      end
    end

    def diff(indent = 0)
      lines = DiffLines.new

      @merged.each_pair do |key, value|
        if @before.nil? || @before[key].nil?
          lines.concat(yaml_lines({key => value}, indent, 'added'))

        elsif @after.nil? || @after[key].nil?
          lines.concat(yaml_lines({key => value}, indent, 'removed'))

        elsif @before[key].is_a?(Array) && @after[key].is_a?(Array)
          lines.concat(compare_arrays(@before[key], @after[key], key, indent))

        elsif value.is_a?(Hash)
          changeset = Changeset.new(@before[key], @after[key])
          diff_lines = changeset.diff(indent+1)
          unless diff_lines.empty?
            lines << Line.new(indent, "#{key}:", nil)
            lines.concat(diff_lines)
          end

        elsif @before[key] != @after[key]
          lines << Line.new(indent, "#{key}: #{@before[key]}", 'removed')
          lines << Line.new(indent, "#{key}: #{@after[key]}", 'added')
        end
      end
      lines
    end

    def yaml_lines(value, indent, state)
      lines = DiffLines.new
      value.to_yaml(indent: Line::INDENT).gsub("---\n", '').split("\n").each do |line|
        lines << Line.new(indent, line, state)
      end
      lines
    end

    def compare_arrays(old_value, new_value, parent_name, indent)
      added = new_value - old_value
      removed = old_value - new_value

      lines = DiffLines.new

      added.each do |elem|
        if elem.is_a?(Hash)
          using_names = (added+removed).all? { |e| e['name'] }
          using_ranges = (added+removed).all? { |e| e['range'] }
          if using_names || using_ranges
            if using_names
              removed_same_name_element = removed.find { |e| e['name'] == elem['name'] }
            elsif using_ranges
              removed_same_name_element = removed.find { |e| e['range'] == elem['range'] }
            end
            removed.delete(removed_same_name_element)

            if removed_same_name_element
              changeset = Changeset.new(removed_same_name_element, elem)
              diff_lines = changeset.diff(indent+1)

              unless diff_lines.empty?
                # write name if elem has been changed
                if using_names
                  lines.concat(yaml_lines([{'name' => elem['name']}], indent, nil))
                elsif using_ranges
                  lines.concat(yaml_lines([{'range' => elem['range']}], indent, nil))
                end
                lines.concat(diff_lines)
              end
            else
              lines.concat(yaml_lines([elem], indent, 'added'))
            end

          else
            lines.concat(yaml_lines([elem], indent, 'added'))
          end
        else
          lines.concat(yaml_lines([elem], indent, 'added'))
        end
      end

      unless removed.empty?
        lines.concat(yaml_lines(removed, indent, 'removed'))
      end

      unless lines.empty?
        lines.unshift(Line.new(indent, "#{parent_name}:", nil))
      end

      lines
    end
  end
end
