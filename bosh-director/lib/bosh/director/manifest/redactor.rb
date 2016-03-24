module Bosh::Director
  class Redactor
    REDACT_KEY_NAMES = %w(
      properties
      bosh
    )

    def self.redact_properties(obj, redact = true ,redact_key_is_ancestor = false)
      return obj unless redact
      if redact_key_is_ancestor
        if obj.respond_to?(:key?)
          obj.keys.each{ |key|
            if obj[key].respond_to?(:each)
              redact_properties(obj[key], redact, true)
            else
              obj[key] = '<redacted>'
            end
          }
        elsif obj.respond_to?(:each_index)
          obj.each_index { |i|
            if obj[i].respond_to?(:each)
              redact_properties(obj[i], redact, true)
            else
              obj[i] = '<redacted>'
            end
          }
        end
      else
        if obj.respond_to?(:each)
          obj.each{ |a|
            if obj.respond_to?(:key?) && REDACT_KEY_NAMES.any? { |key| key == a.first } && a.last.respond_to?(:key?)
              redact_properties(a.last, redact, true)
            else
              redact_properties(a.respond_to?(:last) ? a.last : a, redact)
            end

          }
        end
      end

      obj
    end
  end
end
