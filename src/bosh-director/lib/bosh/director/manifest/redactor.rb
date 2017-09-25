module Bosh::Director
  class Redactor

    REDACT_KEY_NAMES = %w(
      properties
      bosh
    )
    REDACT_STRING = '<redacted>'

    # redacts properties from ruby object to avoid having to use a regex to redact properties from diff output
    # please do not use regexes for diffing/redacting
    def redact_properties!(object)
      redact_known_key_properties!(object)
      redact_credentials_in_release_urls!(object)
      object
    end

    private

    def redact_known_key_properties!(object)
      if iterable?(object)
        object.each{ |item|
          if hash?(object) && key_to_redact?(item_key(item)) && hash?(item_value(item))
            redact_values!(item_value(item))
          else
            redact_known_key_properties!(item.respond_to?(:last) ? item_value(item) : item)
          end
        }
      end
    end

    def redact_values!(object)
      if hash?(object)
        object.keys.each {|key|
          if iterable?(object[key])
            redact_values!(object[key])
          else
            object[key] = REDACT_STRING
          end
        }
      elsif array?(object)
        object.each_index {|i|
          if iterable?(object[i])
            redact_values!(object[i])
          else
            object[i] = REDACT_STRING
          end
        }
      end
    end

    def redact_credentials_in_release_urls!(object)
      releases = hash?(object) ? object['releases'] : nil
      return if releases.nil? || !array?(releases)

      releases.each_index{ |i|
        release_url_value = releases[i]['url']
        next if release_url_value.nil?
        begin
          release_uri = URI.parse(release_url_value)

          release_url_value.sub!(release_uri.user, REDACT_STRING) if release_uri.user
          release_url_value.sub!(release_uri.password, REDACT_STRING) if release_uri.password
        rescue URI::Error
          # ignore bad urls
        end
      }
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
