require 'db_migrator'

module Bosh::Director
  class Worker
    MAX_MIGRATION_ATTEMPTS = 50

    def initialize(config, index = 0, retry_interval = 0.5)
      @config = config
      @index = index
      @retry_interval = retry_interval
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
      queues << @config.director_pool unless @config.director_pool.nil? || (queues - ['urgent']).empty?

      @delayed_job_worker = Delayed::Worker.new({:queues => queues})
      trap('USR1') {
        @delayed_job_worker.queues = [ 'non_existent_queue' ]
      } #stop accepting new jobs when USR1 is sent
    end

    def start
      @delayed_job_worker.name = "worker_#{@index}"
      @delayed_job_worker.logger.info("Starting worker #{@delayed_job_worker.name}.")
      Bosh::Director::Config.log_director_start_event('worker', @delayed_job_worker.name, {})
      migrator = DBMigrator.new(@config.db, :director)
      tries = 0
      until migrator.current?
        tries += 1
        sleep @retry_interval
        if tries >= MAX_MIGRATION_ATTEMPTS
          @delayed_job_worker.logger.error("Migrations not current during worker start after #{tries} attempts.")
          raise "Migrations not current after #{MAX_MIGRATION_ATTEMPTS} retries"
        end
      end

      begin
        @delayed_job_worker_retries ||= 0
        @delayed_job_worker.start
      rescue Exception => e
        @delayed_job_worker.logger.error("Something goes wrong during worker start. Attempt #{@delayed_job_worker_retries}. Error: #{e.inspect}")
        while @delayed_job_worker_retries < 10
          @delayed_job_worker_retries += 1
          sleep @retry_interval
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
