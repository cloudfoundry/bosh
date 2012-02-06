module Bosh::Director

  class InstanceDeleter

    def initialize
      @cloud = Config.cloud
      @logger = Config.logger

    end


  end

end
def delete_instance(instance, vm)
  @logger.info("Delete unneeded instance #{vm.cid}")

  agent = AgentClient.new(vm.agent_id)
  drain_time = agent.drain("shutdown")
  sleep(drain_time)
  agent.stop

  @cloud.delete_vm(vm.cid)
  instance.persistent_disks.each do |disk|
    @logger.info("Deleting inactive disk #{disk.disk_cid}") unless disk.active
    begin
      @cloud.delete_disk(disk.disk_cid)
    rescue DiskNotFound
      raise if disk.active
    end
    disk.destroy
  end

  vm.db.transaction do
    instance.destroy
    vm.destroy
  end

  if Config.dns_enabled?
    record_pattern = "#{instance.index}.#{@job.name}.%.#{@deployment.name}.bosh"
    records = Models::Dns::Record.filter(:domain_id => @deployment.dns_domain.id).
        filter(:name.like(record_pattern))
    records.each { |record| record.destroy }
  end
end