module Bosh::Cli::TaskTracking
  class TaskLogRenderer
    def self.create_for_log_type(log_type)
      if log_type == 'event'
        EventLogRenderer.new
      elsif log_type == 'result' || log_type == 'none'
        NullTaskLogRenderer.new
      else
        TaskLogRenderer.new
      end
    end

    attr_accessor :time_adjustment
    attr_accessor :duration

    def initialize
      @out = Bosh::Cli::Config.output || $stdout
      @out.sync = true
      @output = ''

      @time_adjustment = 0
      @duration = nil
    end

    def add_output(output)
      @output = output
    end

    def refresh
      @out.print(@output)
      @output = ''
    end

    def finish(state)
      refresh
    end

    def duration_known?
      false
    end
  end
end
