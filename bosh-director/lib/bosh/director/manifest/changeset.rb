module Bosh::Director
  class Changeset
    KEY_NAME = 'name'

    REDACT_KEY_NAMES = %w(
      properties
      bosh
    )

    def initialize(before, after, redacted_before = nil, redacted_after = nil)
      @redacted_before = redacted_before.nil? ? Changeset.redact_properties!(Bosh::Common::DeepCopy.copy(before)) : redacted_before
      @redacted_after = redacted_after.nil? ? Changeset.redact_properties!(Bosh::Common::DeepCopy.copy(after)) : redacted_after

      @before = before
      @after = after

      if @before && @after
        @merged = deep_merge(@before, @after)
      elsif @before
        @merged = @before
      else
        @merged = @after
      end
    end

    # redacts properties from ruby object to avoid having to use a regex to redact properties from diff output
    # please do not use regexes for diffing/redacting
    def self.redact_properties!(obj, redact_key_is_ancestor = false)
      if redact_key_is_ancestor
        if obj.respond_to?(:key?)
          obj.keys.each{ |key|
            if obj[key].respond_to?(:each)
              redact_properties!(obj[key], true)
            else
              obj[key] = '<redacted>'
            end
          }
        elsif obj.respond_to?(:each_index)
          obj.each_index { |i|
            if obj[i].respond_to?(:each)
              redact_properties!(obj[i], true)
            else
              obj[i] = '<redacted>'
            end
          }
        end
      else
        if obj.respond_to?(:each)
          obj.each{ |a|
            if obj.respond_to?(:key?) && REDACT_KEY_NAMES.any? { |key| key == a.first } && a.last.respond_to?(:key?)
              redact_properties!(a.last, true)
            else
              redact_properties!(a.respond_to?(:last) ? a.last : a)
            end

          }
        end
      end

      obj
    end

    def diff(redact=true, indent = 0)
      lines = DiffLines.new

      if redact
        output_values_before = @redacted_before
        output_values_after = @redacted_after
      else
        output_values_before = @before
        output_values_after = @after
      end

      @merged.each_pair do |key, value|
        if @before[key] != @after[key]
          if @before.nil? || @before[key].nil?
            lines.concat(yaml_lines({key => output_values_after[key]}, indent, 'added'))

          elsif @after.nil? || @after[key].nil?
            lines.concat(yaml_lines({key => output_values_before[key]}, indent, 'removed'))

          elsif @before[key].is_a?(Array) && @after[key].is_a?(Array)
            lines.concat(compare_arrays(@before[key], @after[key], output_values_before[key], output_values_after[key], key, redact, indent))

          elsif @before[key].is_a?(Hash) && @after[key].is_a?(Hash)
            changeset = Changeset.new(@before[key], @after[key], output_values_before[key], output_values_after[key])
            diff_lines = changeset.diff(redact, indent+1)
            unless diff_lines.empty?
              lines << Line.new(indent, "#{key}:", nil)
              lines.concat(diff_lines)
            end

          else
            lines.concat(yaml_lines({key => output_values_before[key]}, indent, 'removed'))
            lines.concat(yaml_lines({key => output_values_after[key]}, indent, 'added'))
          end
        end
      end
      lines
    end

    private

    def deep_merge(first, second)
      merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
      first.merge(second, &merger)
    end

    def yaml_lines(value, indent, state)
      lines = DiffLines.new
      value.to_yaml(indent: Line::INDENT).gsub(/^---\n/, '').split("\n").each do |line|
        lines << Line.new(indent, line, state)
      end
      lines
    end

    def compare_arrays(old_value, new_value, output_old_value, output_new_value, parent_name, redact, indent)
      # combine arrays of redacted and unredacted values. unredacted arrays for diff logic, and redacted arrays for output
      combined_old_value = old_value.zip output_old_value
      combined_new_value = new_value.zip output_new_value
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
            if using_names
              removed_same_name_element = removed.find { |e| e.first['name'] == elem['name'] }
            elsif using_ranges
              removed_same_name_element = removed.find { |e| e.first['range'] == elem['range'] }
            end
            removed.delete(removed_same_name_element)

            if removed_same_name_element
              changeset = Changeset.new(removed_same_name_element.first, elem, removed_same_name_element.last, redacted_elem)
              diff_lines = changeset.diff(redact, indent+1)

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
