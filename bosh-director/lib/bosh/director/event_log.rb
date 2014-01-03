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
      def initialize(io = nil)
        @logger = CustomLogger.new(io || StringIO.new)
        @last_stage = Stage.new(self, 'unknown', [], 0)
      end

      def begin_stage(stage_name, total = nil, tags = [])
        @last_stage = Stage.new(self, stage_name, tags, total)
      end

      def track(task_name = nil, &blk)
        @last_stage.advance_and_track(task_name, &blk)
      end

      # Adds an error entry to the event log.
      # @param [DirectorError] error Director error
      # @return [void]
      def log_error(error)
        @logger.info(Yajl::Encoder.encode(
          :time => Time.now.to_i,
          :error => {
            :code => error.error_code,
            :message => error.message,
          },
        ))
      end

      def log_entry(entry)
        @logger.info(Yajl::Encoder.encode(entry))
      end
    end

    class Stage
      def initialize(event_log, name, tags, total)
        @event_log = event_log
        @name = name
        @tags = tags
        @index = 0
        @total = total
        @index_lock = Mutex.new
      end

      def advance_and_track(task_name, &blk)
        task = @index_lock.synchronize do
          @index += 1
          Task.new(self, task_name, @index)
        end

        task.start
        begin
          blk.call(task) if blk
        rescue => e
          task.failed(e.to_s)
          raise
        end
        task.finish
      end

      def log_entry(entry)
        @event_log.log_entry({
          :time => Time.now.to_i,
          :stage => @name,
          :tags => @tags,
          :total => @total,
        }.merge(entry))
      end
    end

    class Task
      def initialize(stage, name, index)
        @stage = stage
        @name = name
        @index = index
        @state = 'in_progress'
        @progress = 0
      end

      def advance(delta, data = {})
        @state = 'in_progress'
        @progress = [@progress + delta, 100].min
        log_entry(data)
      end

      def start
        @state = 'started'
        log_entry
      end

      def finish
        @state = 'finished'
        @progress = 100
        log_entry
      end

      def failed(error_msg = nil)
        @state = 'failed'
        @progress = 100
        log_entry("error" => error_msg)
      end

      private

      def log_entry(data = {})
        task_entry = {
          :task => @name,
          :index => @index,
          :state => @state,
          :progress => @progress.to_i,
        }
        task_entry[:data] = data if data.size > 0
        @stage.log_entry(task_entry)
      end
    end

    class CustomLogger < ::Logger
      def format_message(level, time, progname, msg)
        msg + "\n"
      end
    end
  end
end
