module Bosh::Cli
  class TaskLogRenderer

    def self.create_for_log_type(log_type, output_fn = nil)
      if log_type == "event"
        EventLogRenderer.new
      else
        TaskLogRenderer.new(output_fn)
      end
    end

    attr_accessor :time_adjustment
    attr_accessor :duration

    def initialize(output_fn = nil)
      @out = Bosh::Cli::Config.output || $stdout
      @out.sync = true
      @lock = Mutex.new
      @output = ""
      @time_adjustment = 0
      @output_fn = output_fn
    end

    def add_output(output)
      output = @output_fn.call(output) unless @output_fn.nil?
      @output += output.to_s
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
