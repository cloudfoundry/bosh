module Bosh::Director
  class Redactor
    REDACT_KEY_NAMES = %w(
      properties
      bosh
    )

    def self.mark_properties_for_redaction(obj, redact_key_is_ancestor = false, redaction_marker = '<redact this!!!>' )

      if redact_key_is_ancestor
        if obj.respond_to?(:key?)
          obj.keys.each{ |key|
            if obj[key].respond_to?(:each)
              mark_properties_for_redaction(obj[key], true)
            else
              obj[key] = "#{obj[key].to_s.gsub(/\n/, '\n')}#{redaction_marker}"
            end
          }
        elsif obj.respond_to?(:each_index)
          obj.each_index { |i|
            if obj[i].respond_to?(:each)
              mark_properties_for_redaction(obj[i], true)
            else
              obj[i] = "#{obj[i].to_s.gsub(/\n/, '\n')}#{redaction_marker}"
            end
          }
        end
      else
        if obj.respond_to?(:each)
          obj.each{ |a|
            if obj.respond_to?(:key?) && REDACT_KEY_NAMES.any? { |key| key == a.first } && a.last.respond_to?(:key?)
              mark_properties_for_redaction(a.last, true)
            else
              mark_properties_for_redaction(a.respond_to?(:last) ? a.last : a)
            end

          }
        end
      end
      obj
    end


    def self.redact_difflines_marked_for_redaction diff_lines
      redaction_marker = '<redact this!!!>'
      redaction_message = '<redacted>'

      diff_lines.each do |diffline|
        next unless diffline.text.match(redaction_marker)

        case diffline.text
        when /^[^'":]+:/
          diffline.text.gsub!(/(^[^'":]+):.*$/, "\\1: #{redaction_message}")
        when /^(\s*-\s*).*$/
          diffline.text.gsub!(/^(\s*-\s*).*$/, "\\1#{redaction_message}")
        else
          diffline.text = redaction_message
        end
      end

      diff_lines
    end
  end


end
