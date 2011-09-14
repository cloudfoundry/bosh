module Bosh::Director
  module Jobs
    class BaseJob
      attr_accessor :task_id

      def initialize(*args)
        # TODO: this logger and event_log are wrong one (default defined in Config.logger)
        # it will be changed later in perform
        # We need to refactor to have all the init work done in initialize and not in perform
        # Meanwhile we need this to allow unit-test to pass (perform is not always first function to be called)
        @logger = Config.logger
        @event_log = Config.event_log
      end

      def self.perform(task_id, *args)
        task = Models::Task[task_id]
        raise TaskNotFound.new(task_id) if task.nil?

        logger = Logger.new(File.join(task.output, "debug"))
        logger.level = Config.logger.level
        logger.formatter = ThreadFormatter.new
        logger.info("Starting task: #{task_id}")

        Config.event_log = Bosh::Director::EventLog.new(File.join(task.output, "event"))
        @event_log = Config.event_log

        Config.logger = logger

        Sequel::Model.db.logger = logger

        cloud_options = Config.cloud_options
        if cloud_options && cloud_options["plugin"] == "vsphere"
          cloud_options["properties"]["soap_log"] = File.join(task.output, "soap")
          Config.cloud_options = cloud_options
        end

        started = Time.now
        with_thread_name("task:#{task_id}") do
          begin
            logger.info("Creating job")
            job = self.send(:new, *args)
            job.task_id = task_id
            job.task_checkpoint # cancelled in the queue?

            logger.info("Performing task: #{task_id}")
            task.state = :processing
            task.timestamp = Time.now
            task.checkpoint_time = Time.now
            task.save

            Thread.new do
              with_thread_name("task:#{task_id}-checkpoint") do
                while true
                  sleep(Config.task_checkpoint_interval)
                  task = Models::Task[task_id]
                  task.checkpoint_time = Time.now
                  task.save
                end
              end
            end
            result = job.perform

            logger.info("Done")
            task.state = :done
            task.result = result
            task.timestamp = Time.now
            task.save
          rescue Exception => e
            if e.kind_of?(Bosh::Director::TaskCancelled)
              logger.info("task #{task_id} cancelled!")
              task.state = :cancelled
            else
              logger.error("#{e} - #{e.backtrace.join("\n")}")
              task.state = :error
            end
            task.result = e.to_s
            task.timestamp = Time.now
            task.save
          end
        end
        ended = Time.now
        logger.info("Task took #{Duration.duration(ended - started)} to process.")
      end

      def task_checkpoint
        task = Models::Task[@task_id]
        if task && (task.state == "cancelling" || task.state == "timeout")
          raise TaskCancelled.new(@task_id)
        end
      end

      def track_and_log(task)
        @event_log.track(task) do |ticker|
          @logger.info(task)
          yield ticker if block_given?
        end
      end
    end
  end
end
