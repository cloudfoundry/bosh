require 'cli/core_ext'

module Bosh::Deployer
  class UiMessager
    include BoshExtensions

    class UnknownMessageName < StandardError; end

    def self.for_deployer(options = {})
      new(
        {
        update_stemcell_unknown: 'Will deploy because new stemcell fingerprint is unknown',
        update_stemcell_changed: 'Will deploy due to stemcell changes',
        update_config_changed:   'Will deploy due to configuration changes',
        update_no_changes:       'Will skip deploy due to no changes',
        },
        options)
    end

    def initialize(messages, options = {})
      @messages = messages
      @options = options
    end

    def info(message_name)

      raise ArgumentError, 'message_name must be a Symbol' unless message_name.is_a?(Symbol)

      message = @messages[message_name]
      if message
        say(message) unless @options[:silent]
      else
        raise UnknownMessageName, message_name
      end
    end
  end
end
