module Bosh::Director::ConfigServer
  module ConfigServerHelper

    # Checks if string starts with '((' and ends with '))'
    # @param [String] value string to be checked
    # @return [Boolean] true is it starts with '((' and ends with '))'
    def is_placeholder?(value)
      value.to_s.match(/^\(\(.*\)\)$/)
    end

    # @param [String] placeholder
    # @return [String] placeholder key stripped from starting and ending brackets
    # @raise [Error] if key does not meet specs
    def extract_placeholder_key(placeholder)
      key = placeholder.to_s.gsub(/(^\(\(|\)\)$)/, '')
      validate_placeholder_key(key)
      process_key(key)
    end

    private

    def validate_placeholder_key(key)
      # Allowing exclamation mark for spiff
      unless /^[a-zA-Z0-9_\-!\/]+$/ =~ key
        raise Bosh::Director::ConfigServerIncorrectKeySyntax,
              "Placeholder key '#{key}' should include alphanumeric, underscores, dashes, or forward slash characters"
      end

      if key.end_with? '/'
        raise Bosh::Director::ConfigServerIncorrectKeySyntax,
              "Placeholder key '#{key}' should not end with a forward slash"
      end

      if /\/\// =~ key
        raise Bosh::Director::ConfigServerIncorrectKeySyntax,
              "Placeholder key '#{key}' should not contain two consecutive forward slashes"
      end

      validate_bang_character(key)
    end

    def validate_bang_character(key)
      bang_count = key.scan(/!/).count
      if bang_count > 1
        raise Bosh::Director::ConfigServerIncorrectKeySyntax, bang_error_msg(key)
      elsif bang_count == 1
        unless key.start_with?('!') && key.size != 1
          raise Bosh::Director::ConfigServerIncorrectKeySyntax, bang_error_msg(key)
        end
      end
    end

    def bang_error_msg(key)
      "Placeholder key '#{key}' contains invalid character '!'. If it is included for spiff, " +
        'it should only be at the beginning of the key. Note: it will not be considered a part of the key'
    end

    def process_key(key)
      key.gsub(/^!/, '') # remove ! because of spiff
    end
  end
end
