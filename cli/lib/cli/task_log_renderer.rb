# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli
  class TaskLogRenderer

    def self.create_for_log_type(log_type)
      if log_type == "event"
        EventLogRenderer.new
      elsif log_type == "result"
        # Null renderer doesn't output anything to screen, so it fits well
        # in case we need to fetch task result log only, without rendering it
        NullRenderer.new
      else
        TaskLogRenderer.new
      end
    end

    attr_accessor :time_adjustment
    attr_accessor :duration

    def initialize
      @out = Bosh::Cli::Config.output || $stdout
      @out.sync = true
      @lock = Mutex.new
      @output = ""
      @time_adjustment = 0
      @duration = nil
    end

    def duration_known?
      false # TODO: make it available for basic renderer
    end

    def add_output(output)
      @output = output
    end

    def refresh
      @out.print(@output)
      @output = ""
    end

    def finish(state)
      refresh
      @done = true
    end

  end
end
