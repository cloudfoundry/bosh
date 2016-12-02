# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli
  module CommandDiscovery

    def usage(string = nil)
      @usage = string
    end

    def desc(string)
      @desc = string
    end

    def option(name, *args)
      (@options ||= []) << [name, args]
    end

    # @param [Symbol] method_name Method name
    def method_added(method_name)
      if @usage && @desc
        @options ||= []
        method = instance_method(method_name)
        register_command(method, @usage, @desc, @options)
      end
      @usage = nil
      @desc = nil
      @options = []
    end

    # @param [UnboundMethod] method Method implementing the command
    # @param [String] usage Command usage (used to parse command)
    # @param [String] desc Command description
    # @param [Array] options Command options
    def register_command(method, usage, desc, options = [])
      command = CommandHandler.new(self, method, usage, desc, options)
      Bosh::Cli::Config.register_command(command)
    end

  end
end