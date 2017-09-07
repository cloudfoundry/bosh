module Bosh::Director
  class Redactor

    REDACT_KEY_NAMES = %w(
      properties
      bosh
    )

    # redacts properties from ruby object to avoid having to use a regex to redact properties from diff output
    # please do not use regexes for diffing/redacting
    def redact_properties!(object)
      if iterable?(object)
        object.each{ |item|
          if hash?(object) && key_to_redact?(item_key(item)) && hash?(item_value(item))
            redact_values!(item_value(item))
          else
            redact_properties!(item.respond_to?(:last) ? item_value(item) : item)
          end
        }
      end

      object
    end

    private

    def redact_values!(object)
      if hash?(object)
        object.keys.each {|key|
          if iterable?(object[key])
            redact_values!(object[key])
          else
            object[key] = '<redacted>'
          end
        }
      elsif array?(object)
        object.each_index {|i|
          if iterable?(object[i])
            redact_values!(object[i])
          else
            object[i] = '<redacted>'
          end
        }
      end
    end

    def hash?(obj)
      obj.respond_to?(:key?)
    end

    def array?(obj)
      obj.respond_to?(:each_index)
    end

    def iterable?(obj)
      obj.respond_to?(:each)
    end

    def item_value(item)
      item.last
    end

    def item_key(item)
      item.first
    end

    def key_to_redact?(key)
      REDACT_KEY_NAMES.any? {|redact_key| redact_key == key}
    end
  end
end
