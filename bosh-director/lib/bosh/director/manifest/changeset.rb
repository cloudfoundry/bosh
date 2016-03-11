class ::Hash
  def deep_merge(second)
    merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
    self.merge(second, &merger)
  end
end

module Bosh::Director
  class Changeset
    KEY_NAME = 'name'

    def initialize(before, after, redact = true, redacted_before = nil, redacted_after = nil)
      @redact = redact
      @redacted_before = redacted_before.nil? ? Redactor.redact_properties(Bosh::Common::DeepCopy.copy(before), redact) : redacted_before
      @redacted_after = redacted_after.nil? ? Redactor.redact_properties(Bosh::Common::DeepCopy.copy(after), redact) : redacted_after

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
          lines.concat(yaml_lines({key => @redacted_after[key]}, indent, 'added'))

        elsif @after.nil? || @after[key].nil?
          lines.concat(yaml_lines({key => @redacted_before[key]}, indent, 'removed'))

        elsif @before[key].is_a?(Array) && @after[key].is_a?(Array)
          lines.concat(compare_arrays(@before[key], @after[key], @redacted_before[key], @redacted_after[key], key, indent))

        elsif value.is_a?(Hash)
          changeset = Changeset.new(@before[key], @after[key],@redact, @redacted_before[key], @redacted_after[key])
          diff_lines = changeset.diff(indent+1)
          unless diff_lines.empty?
            lines << Line.new(indent, "#{key}:", nil)
            lines.concat(diff_lines)
          end

        elsif @before[key] != @after[key]
          lines.concat(yaml_lines({key => @redacted_before[key]}, indent, 'removed'))
          lines.concat(yaml_lines({key => @redacted_after[key]}, indent, 'added'))
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

    def compare_arrays(old_value, new_value, redacted_old_value, redacted_new_value, parent_name, indent)
      # combine arrays of redacted and unredacted values. unredacted arrays for diff logic, and redacted arrays for output
      combined_old_value = old_value.zip redacted_old_value
      combined_new_value = new_value.zip redacted_new_value

      added = combined_new_value - combined_old_value
      removed = combined_old_value - combined_new_value

      lines = DiffLines.new

      added.each do |pair|

        elem = pair.first
        redacted_elem = pair.last

        if elem.is_a?(Hash)
          using_names = (added+removed).all? { |e| e.first['name'] }

          using_ranges = (added+removed).all? { |e| e.first['range'] }
          if using_names || using_ranges
            #clean up duplicate values
            if using_names
              removed_same_name_element = removed.find { |e| e.first['name'] == elem['name'] }
            elsif using_ranges
              removed_same_name_element = removed.find { |e| e.first['range'] == elem['range'] }
            end
            removed.delete(removed_same_name_element)

            if removed_same_name_element
              changeset = Changeset.new(removed_same_name_element.first, elem, @redact, removed_same_name_element.last, redacted_elem)
              diff_lines = changeset.diff(indent+1)

              unless diff_lines.empty?
                # write name if elem has been changed
                if using_names
                  lines.concat(yaml_lines([{'name' => redacted_elem['name']}], indent, nil))
                elsif using_ranges
                  lines.concat(yaml_lines([{'range' => redacted_elem['range']}], indent, nil))
                end
                lines.concat(diff_lines)
              end
            else
              lines.concat(yaml_lines([redacted_elem], indent, 'added'))
            end

          else
            lines.concat(yaml_lines([redacted_elem], indent, 'added'))
          end
        else
          lines.concat(yaml_lines([redacted_elem], indent, 'added'))
        end
      end

      unless removed.empty?
        redacted_removed = []
        removed.each do |pair| redacted_removed.push(pair.last) end
        lines.concat(yaml_lines(redacted_removed, indent, 'removed'))
      end

      unless lines.empty?
        lines.unshift(Line.new(indent, "#{parent_name}:", nil))
      end

      lines
    end
  end
end
