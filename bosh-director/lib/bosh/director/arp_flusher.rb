module Bosh::Director
  class ArpFlusher
    def delete_arp_entries(vm_cid_to_exclude, ip_addresses)
      filtered_instances = filter_instances(vm_cid_to_exclude)

      ThreadPool.new(:max_threads => Config.max_threads).wrap do |pool|
        filtered_instances.each do |instance|
          pool.process do
            agent = AgentClient.with_vm_credentials_and_agent_id(instance.credentials, instance.agent_id)
            agent.delete_arp_entries(ips: ip_addresses)
          end
        end
      end
    end

    def filter_instances(vm_cid_to_exclude)
      Models::Instance
        .exclude(vm_cid: nil)
        .exclude(vm_cid: vm_cid_to_exclude)
        .exclude(compilation: true).all
    end
  end
end
