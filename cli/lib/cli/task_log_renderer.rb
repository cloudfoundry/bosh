module Bosh::Cli
  class TaskLogRenderer

    def self.create_for_log_type(log_type)
      if log_type == "event"
        EventLogRenderer.new
      else
        TaskLogRenderer.new
      end
    end

    def initialize
      @out = Bosh::Cli::Config.output || $stdout
      @out.sync = true
      @lock = Mutex.new
      @output = ""
    end

    def add_output(output)
      @output = output
    end

    def refresh
      @out.print(@output)
      @output = ""
    end

    def done
      refresh
      @done = true
    end

  end
end
