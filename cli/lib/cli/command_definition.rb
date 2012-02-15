# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli
  class CommandDefinition
    attr_reader :options
    attr_reader :power_options
    attr_reader :keywords

    def initialize
      @options = []
      @power_options = []
      @hints = []
      @keywords = []
    end

    def usage(str = nil)
      if str
        @usage = str.strip
        @keywords = str.split(/\s+/).select do |word|
          word.match(/^[a-z]/i)
        end
      else
        @usage
      end
    end

    def description(str = nil)
      str ? (@description = str.to_s.strip) : @description
    end

    alias :desc :description

    def option(name, value = "")
      @options << [ name, value ]
    end

    def power_option(name, value = "")
      @power_options << [ name, value ]
    end

    def route(*args, &block)
      if args.size > 0
        @route = args
      elsif block_given?
        @route = block
      else
        @route
      end
    end
  end
end

