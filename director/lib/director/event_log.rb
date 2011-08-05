module Bosh::Director

  class EventLog

    # Event log conventions:
    # All event log entries having same "stage" logically belong to the same event group.
    # "tags" is an array of strings that supposed to act as hint of what is being tracked.
    # Each "<stage name> <tags>" combination represents a number of steps that is tracked
    # separately.
    # "task" is just a description of current step that acts as a hint for event log renderer,
    # i.e. it can be displayed next to progress bar.
    # Example: "job_update" stage might have two tasks: "canary update" and "update"
    # and a separate tag for each job name, so each job will have a separate progress
    # bar in CLI.

    # Sample rendering for event log entry:
    # {"time":1312233461,"stage":"job_update","task":"update","tags":["mysql_node"],"index":2,"total":4,"state":"finished"}

    # Job update (mysql_node):
    # update |--------        | (2/4) 50%

    attr_reader :stage
    attr_reader :total
    attr_reader :counter

    def initialize(io = nil)
      @logger = EventLogger.new(io || StringIO.new)
      @lock = Mutex.new
      @counter = 0
    end

    def begin_stage(stage, total = nil, tags = [])
      @lock.synchronize do
        @stage = stage
        @tags = tags
        @counter = 0
        @total = total
      end
    end

    def track(task = nil, total = nil)
      index = nil
      @lock.synchronize do
        @counter += 1
        index = @counter
      end

      start_task(task, index)
      yield
      finish_task(task, index)
    end

    def start_task(task, index)
      log(task, "started", index)
    end

    def finish_task(task, index)
      log(task, "finished", index)
    end

    private

    def log(task, state, index)
      entry = {
        :time  => Time.now.to_i,
        :stage => @stage,
        :task  => task,
        :tags  => @tags,
        :index => index,
        :total => @total,
        :state => state
      }

      @logger.info(Yajl::Encoder.encode(entry))
    end
  end

  class EventLogger < Logger
    def format_message(level, time, progname, msg)
      msg + "\n"
    end
  end

end
