module Bosh::Director
  module Jobs
    module BaseJob

      def perform(task_id, *args)
        task = Models::Task[task_id]
        raise TaskNotFound.new(task_id) if task.nil?

        logger = Logger.new(File.join(task.output, "debug"))
        logger.level = Config.logger.level
        logger.formatter = ThreadFormatter.new
        logger.info("Starting task: #{task_id}")

        event_log = Bosh::Director::EventLog.new(task_id, File.join(task.output, "event"))
        Config.event_logger = event_log
        Config.logger = logger
        Sequel::Model.db.logger = logger

        cloud_options = Config.cloud_options
        if cloud_options && cloud_options["plugin"] == "vsphere"
          cloud_options["properties"]["soap_log"] =  File.join(task.output, "soap")
          Config.cloud_options = cloud_options
        end

        started = Time.now
        with_thread_name("task:#{task_id}") do
          begin
            logger.info("Creating job")
            job = self.send(:new, *args)

            logger.info("Performing task: #{task_id}")
            task.state = :processing
            task.timestamp = Time.now
            task.checkpoint_time = Time.now
            task.save

            Thread.new do
              with_thread_name("task:#{task_id}-checkpoint") do
                while true
                  sleep(Config.task_checkpoint_interval)
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
            logger.error("#{e} - #{e.backtrace.join("\n")}")
            task.state = :error
            task.result = e.to_s
            task.timestamp = Time.now
            task.save
          end
        end
        ended = Time.now
        logger.info("Task took #{Duration.duration(ended - started)} to process.")
      end

    end
  end
end
