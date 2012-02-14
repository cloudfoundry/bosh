module Bosh::Director
  module Jobs
    class BaseJob

      attr_accessor :task_id

      def initialize(*args)
        @logger = Config.logger
        @event_log = Config.event_log
        @result_file = Config.result
      end

      def self.perform(task_id, *args)
        task = Models::Task[task_id]
        raise TaskNotFound.new(task_id) if task.nil?

        Config.cur_job = nil
        logger = Logger.new(File.join(task.output, "debug"))
        logger.level = Config.logger.level
        logger.formatter = ThreadFormatter.new
        logger.info("Starting task: #{task_id}")

        Config.event_log = Bosh::Director::EventLog.new(File.join(task.output, "event"))
        Config.result = Bosh::Director::TaskResultFile.new(File.join(task.output, "result"))
        Config.logger = logger

        Config.db.logger = logger
        Config.dns_db.logger = logger if Config.dns_enabled?

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
            Config.cur_job = job
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
            task.result = truncate_str(result.to_s)
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
            task.result = truncate_str(e.to_s)
            task.timestamp = Time.now
            task.save
          end
        end
        ended = Time.now
        logger.info("Task took #{Duration.duration(ended - started)} to process.")
      end

      def task_cancelled?
        task = Models::Task[@task_id]
        task && (task.state == "cancelling" || task.state == "timeout")
      end

      def task_checkpoint
        raise TaskCancelled.new(@task_id) if task_cancelled?
      end

      def begin_stage(stage_name, n_steps)
        @event_log.begin_stage(stage_name, n_steps)
        @logger.info(stage_name)
      end

      def track_and_log(task)
        @event_log.track(task) do |ticker|
          @logger.info(task)
          yield ticker if block_given?
        end
      end

      def self.truncate_str(str, len = 128)
        etc = "..."
        stripped = str.strip[0..len]
        if stripped.length > len
          stripped.gsub(/\s+?(\S+)?$/, "") + etc
        else
          stripped
        end
      end
    end
  end
end
