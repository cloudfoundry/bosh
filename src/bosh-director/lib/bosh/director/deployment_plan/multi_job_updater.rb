module Bosh::Director
  module DeploymentPlan
    class SerialMultiJobUpdater
      def initialize(job_updater_factory)
        @job_updater_factory = job_updater_factory
      end

      def run(base_job, deployment_plan, jobs)
        base_job.logger.info("Updating instances serially: #{jobs.map(&:name).join(', ')}")

        jobs.each do |j|
          base_job.task_checkpoint
          base_job.logger.info("Updating instance: #{j.name}")
          job_updater = @job_updater_factory.new_job_updater(deployment_plan, j)
          job_updater.update
        end
      end
    end

    class ParallelMultiJobUpdater
      def initialize(job_updater_factory)
        @job_updater_factory = job_updater_factory
      end

      def run(base_job, deployment_plan, jobs)
        base_job.logger.info("Updating instances in parallel: #{jobs.map(&:name).join(', ')}")
        base_job.task_checkpoint

        ThreadPool.new(max_threads: jobs.size).wrap do |pool|
          jobs.each do |j|
            pool.process do
              base_job.logger.info("Updating instance: #{j.name}")
              job_updater = @job_updater_factory.new_job_updater(deployment_plan, j)
              job_updater.update
            end
          end
        end
      end
    end

    class BatchMultiJobUpdater
      def initialize(job_updater_factory)
        @job_updater_factory = job_updater_factory
      end

      def run(base_job, deployment_plan, jobs)
        serial_updater = SerialMultiJobUpdater.new(@job_updater_factory)
        parallel_updater = ParallelMultiJobUpdater.new(@job_updater_factory)

        partition_jobs_by_serial(jobs).each do |jp|
          updater = jp.first.update.serial? ? serial_updater : parallel_updater
          updater.run(base_job, deployment_plan, jp)
        end
      end

      private

      def partition_jobs_by_serial(jobs)
        job_partitions = []
        last_partition = []

        jobs.each do |j|
          lastj = last_partition.last
          if !lastj || lastj.update.serial? == j.update.serial?
            last_partition << j
          else
            job_partitions << last_partition
            last_partition = [j]
          end
        end

        job_partitions << last_partition if last_partition.any?
        job_partitions
      end
    end
  end
end
