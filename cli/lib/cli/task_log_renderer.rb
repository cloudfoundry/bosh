module Bosh::Cli
  class TaskLogRenderer

    def self.create_for_log_type(log_type)
      if log_type == "event"
        EventLogRenderer.new
      else
        TaskLogRenderer.new
      end
    end

    attr_accessor :time_adjustment

    def initialize
      @out = Bosh::Cli::Config.output || $stdout
      @out.sync = true
      @lock = Mutex.new
      @output = ""
      @time_adjustment = 0
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
