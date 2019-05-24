module Bosh::Director
  module DeploymentPlan
    class SerialMultiInstanceGroupUpdater
      def initialize(instance_group_updater_factory)
        @instance_group_updater_factory = instance_group_updater_factory
      end

      def run(base_job, ip_provider, jobs)
        base_job.logger.info("Updating instances serially: #{jobs.map(&:name).join(', ')}")

        jobs.each do |j|
          base_job.task_checkpoint
          base_job.logger.info("Updating instance: #{j.name}")
          instance_group_updater = @instance_group_updater_factory.new_instance_group_updater(ip_provider, j)
          instance_group_updater.update
        end
      end
    end

    class ParallelMultiInstanceGroupUpdater
      def initialize(instance_group_updater_factory)
        @instance_group_updater_factory = instance_group_updater_factory
      end

      def run(base_job, ip_provider, jobs)
        base_job.logger.info("Updating instances in parallel: #{jobs.map(&:name).join(', ')}")
        base_job.task_checkpoint

        ThreadPool.new(max_threads: jobs.size).wrap do |pool|
          jobs.each do |j|
            pool.process do
              base_job.logger.info("Updating instance: #{j.name}")
              instance_group_updater = @instance_group_updater_factory.new_instance_group_updater(ip_provider, j)
              instance_group_updater.update
            end
          end
        end
      end
    end

    class BatchMultiInstanceGroupUpdater
      def initialize(instance_group_updater_factory)
        @instance_group_updater_factory = instance_group_updater_factory
      end

      def run(base_job, ip_provider, jobs)
        serial_updater = SerialMultiInstanceGroupUpdater.new(@instance_group_updater_factory)
        parallel_updater = ParallelMultiInstanceGroupUpdater.new(@instance_group_updater_factory)

        BatchMultiInstanceGroupUpdater.partition_jobs_by_serial(jobs).each do |jp|
          updater = jp.first.update.serial? ? serial_updater : parallel_updater
          updater.run(base_job, ip_provider, jp)
        end
      end

      def self.partition_jobs_by_serial(jobs)
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
