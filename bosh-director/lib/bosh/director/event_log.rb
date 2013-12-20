module Bosh::Director
  module EventLog
    # Event log conventions:
    # All event log entries having same "stage" logically belong to the same
    # event group. "tags" is an array of strings that supposed to act as hint
    # of what is being tracked.
    # Each "<stage name> <tags>" combination represents a number of steps that
    # is tracked separately. "task" is just a description of current step that
    # acts as a hint for event log renderer, i.e. it can be displayed next to
    # progress bar.
    # Example: "job_update" stage might have two tasks: "canary update" and
    # "update" and a separate tag for each job name, so each job will have
    # a separate progress bar in CLI.

    # Sample rendering for event log entry:
    # {
    #   "time":1312233461,"stage":"job_update","task":"update",
    #   "tags":["mysql_node"], "index":2,"total":4,"state":"finished",
    #   "progress":50,"data":{"key1" => "value1"}
    # }

    # Job update (mysql_node):
    # update |--------        | (2/4) 50%

    class Log
      attr_reader :stage
      attr_reader :total
      attr_reader :counter

      def initialize(io = nil)
        @logger = CustomLogger.new(io || StringIO.new)
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

      def track(task_name = nil, &blk)
        index = nil
        @lock.synchronize do
          @counter += 1
          index = @counter
        end

        task = Task.new(self, task_name, index)

        start_task(task_name, index)
        begin
          blk.call(task) if blk
        rescue => e
          task_failed(task_name, index, 100, e.to_s)
          raise
        end
        finish_task(task_name, index)
      end

      # Adds an error entry to the event log.
      # @param [DirectorError] error Director error
      # @return [void]
      def log_error(error)
        entry = {
          :time => Time.now.to_i,
          :error => {
            :code => error.error_code,
            :message => error.message
          }
        }

        @logger.info(Yajl::Encoder.encode(entry))
      end

      def start_task(task_name, index, progress = 0)
        log_task(task_name, "started", index, progress)
      end

      def finish_task(task_name, index, progress = 100)
        log_task(task_name, "finished", index, progress)
      end

      def task_failed(task_name, index, progress = 100, error = nil)
        log_task(task_name, "failed", index, progress, {"error" => error})
      end

      def log_task(task_name, state, index, progress = 0, data = {})
        entry = {
          :time => Time.now.to_i,
          :stage => @stage,
          :task => task_name,
          :tags => @tags,
          :index => index,
          :total => @total,
          :state => state,
          :progress => progress,
        }

        entry[:data] = data if data.size > 0

        @logger.info(Yajl::Encoder.encode(entry))
      end
    end

    class CustomLogger < ::Logger
      def format_message(level, time, progname, msg)
        msg + "\n"
      end
    end

    class Task
      def initialize(event_log, name, index)
        @event_log = event_log
        @name = name
        @index = index
        @progress = 0
      end

      def advance(delta, data = {})
        @progress = [@progress + delta, 100].min
        @event_log.log_task(@name, "in_progress", @index, @progress.to_i, data)
      end
    end
  end
end
