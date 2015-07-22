require 'bosh/director/rendered_job_templates_cleaner'

module Bosh::Director
  class InstanceOperator

    def initialize(cloud, event_log, logger)
      @event_log = event_log
      @logger = logger
      vm_deleter = VmDeleter.new(cloud, logger)
      @creator = VmCreator.new(cloud, logger, vm_deleter)
      # @updater = InstanceUpdater.new
      # @deleter = InstanceDeleter.new
    end

    def create(instances_with_missing_vms)
      return @logger.info('No missing vms to create') if instances_with_missing_vms.empty?

      counter = instances_with_missing_vms.length
      ThreadPool.new(max_threads: Config.max_threads, logger: @logger).wrap do |pool|
        instances_with_missing_vms.each do |instance|
          pool.process do
            @event_log.track("#{instance.job.name}/#{instance.index}") do
              with_thread_name("create_missing_vm(#{instance.job.name}, #{instance.index}/#{counter})") do
                @logger.info("Creating missing VM")
                disks = [instance.model.persistent_disk_cid].compact
                @creator.create_for_instance(instance, disks)
              end
            end
          end
        end
      end
    end

    def update(instances)
      raise "come back later"
      # @updater.update(instances)
    end

    def delete(instances)
      raise "come back later"
      # @deleter.delete(instances)
    end
  end
end
