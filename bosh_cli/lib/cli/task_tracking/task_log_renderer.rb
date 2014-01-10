module Bosh::Cli::TaskTracking
  class TaskLogRenderer
    EVENT_LOG_STAGES_WITHOUT_PROGRESS_BAR = [
      'Updating job',
      'Deleting unneeded instances',
    ]

    def self.create_for_log_type(log_type)
      if log_type == 'event'
        EventLogRenderer.new(stages_without_progress_bar:
          EVENT_LOG_STAGES_WITHOUT_PROGRESS_BAR)
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
      @lock = Mutex.new
      @output = ''
      @time_adjustment = 0
      @duration = nil
    end

    def duration_known?
      false
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
      @done = true
    end
  end
end
