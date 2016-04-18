module Bosh::Director
  class Worker

    def initialize(config, index=0)
      @config = config
      @index = index
    end

    def prep
      Delayed::Worker.logger = @config.worker_logger

      Bosh::Director::App.new(@config)

      Delayed::Worker.backend = :sequel
      Delayed::Worker.destroy_failed_jobs = true
      Delayed::Worker.sleep_delay = ENV['INTERVAL'] || 1
      Delayed::Worker.max_attempts = 0
      Delayed::Worker.max_run_time = 31536000

      @delayed_job_worker = nil
      queues = (ENV['QUEUES'] || ENV['QUEUE']).to_s.split(',')

      @delayed_job_worker = Delayed::Worker.new({:queues => queues})
      trap('USR1') {
        @delayed_job_worker.queues = [ 'non_existent_queue' ]
      } #stop accepting new jobs when USR1 is sent
    end

    def start
      @delayed_job_worker.name = "worker_#{@index}"
      @delayed_job_worker.logger.info("Starting worker #{@delayed_job_worker.name}.")

      begin
        @delayed_job_worker_retries ||= 0
        @delayed_job_worker.start
      rescue Exception => e
        @delayed_job_worker.logger.error("Something goes wrong during worker start. Attempt #{@delayed_job_worker_retries}. Error: #{e.inspect}")
        while @delayed_job_worker_retries < 10
          @delayed_job_worker_retries += 1
          sleep 0.5
          retry
        end
        @delayed_job_worker.logger.error("Max retries reached. Error: #{e.inspect}")
        raise e
      end
    end

    def queues
      @delayed_job_worker.queues
    end
  end
end
