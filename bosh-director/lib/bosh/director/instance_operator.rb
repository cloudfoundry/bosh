require 'bosh/director/rendered_job_templates_cleaner'

module Bosh::Director
  class InstanceOperator

    def initialize(cloud, event_log, logger)
      @event_log = event_log
      @logger = logger
      vm_deleter = VmDeleter.new(cloud, logger)
      @creator = VmCreator.new(cloud, logger, vm_deleter)
    end

    def create(instances_with_missing_vms)
      return @logger.info('No missing vms to create') if instances_with_missing_vms.empty?

      total = instances_with_missing_vms.size
      @event_log.begin_stage('Creating missing vms', total)

      ThreadPool.new(max_threads: Config.max_threads, logger: @logger).wrap do |pool|
        instances_with_missing_vms.each do |instance|
          pool.process do
            with_thread_name("create_missing_vm(#{instance.job.name}, #{instance.index}/#{total})") do
              @event_log.track("#{instance.job.name}/#{instance.index}") do
                @logger.info('Creating missing VM')
                disks = [instance.model.persistent_disk_cid].compact
                @creator.create_for_instance(instance, disks)
              end
            end
          end
        end
      end
    end

    def update(instances)
      raise NotImplemented
    end

    def delete(instances)
      raise NotImplemented
    end
  end
end
