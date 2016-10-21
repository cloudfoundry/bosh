module Bosh::Director::ConfigServer
  module ConfigServerHelper

    # Checks if string starts with '((' and ends with '))'
    # @param [String] value string to be checked
    # @return [Boolean] true is it starts with '((' and ends with '))'
    def is_placeholder?(value)
      value.to_s.match(/^\(\(.*\)\)$/)
    end

    # @param [String] placeholder
    # @return [String] placeholder name stripped from starting and ending brackets
    # @raise [Error] if name does not meet specs
    def extract_placeholder_name(placeholder)
      name = placeholder.to_s.gsub(/(^\(\(|\)\)$)/, '')
      validate_placeholder_name(name)
      process_name!(name)
    end

    # @param [String] name
    # @param [String] director_name
    # @param [String] deployment_name
    # @return [String] name prepended with /:director_name/:deployment_name if name is not absolute
    def add_prefix_if_not_absolute(name, director_name, deployment_name)
      return name if name.start_with?('/')
      return "/#{director_name}/#{deployment_name}/#{name}"
    end

    private

    def validate_placeholder_name(name)
      # Allowing exclamation mark for spiff
      unless /^[a-zA-Z0-9_\-!\/]+$/ =~ name
        raise Bosh::Director::ConfigServerIncorrectNameSyntax,
              "Placeholder name '#{name}' must only contain alphanumeric, underscores, dashes, or forward slash characters"
      end

      if name.end_with? '/'
        raise Bosh::Director::ConfigServerIncorrectNameSyntax,
              "Placeholder name '#{name}' must not end with a forward slash"
      end

      if /\/\// =~ name
        raise Bosh::Director::ConfigServerIncorrectNameSyntax,
              "Placeholder name '#{name}' must not contain two consecutive forward slashes"
      end

      validate_bang_character(name)
    end

    def validate_bang_character(name)
      bang_count = name.scan(/!/).count
      if bang_count > 1
        raise Bosh::Director::ConfigServerIncorrectNameSyntax, bang_error_msg(name)
      elsif bang_count == 1
        unless name.start_with?('!') && name.size != 1
          raise Bosh::Director::ConfigServerIncorrectNameSyntax, bang_error_msg(name)
        end
      end
    end

    def bang_error_msg(name)
      "Placeholder name '#{name}' contains invalid character '!'. If it is included for spiff, " +
        'it should only be at the beginning of the name. Note: it will not be considered a part of the name'
    end

    def process_name!(name)
      name.gsub(/^!/, '') # remove ! because of spiff
    end
  end
end
