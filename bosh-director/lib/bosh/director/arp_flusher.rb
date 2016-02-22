module Bosh::Director
  class ArpFlusher
    def delete_from_arp(vm_cid_to_exclude, ip_addresses)
      filtered_instances = filter_instances(vm_cid_to_exclude)

      filtered_instances.each do |instance|
        agent = AgentClient.with_vm_credentials_and_agent_id(instance.credentials, instance.agent_id)
        agent.wait_until_ready
        agent.delete_from_arp(ips: ip_addresses)
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
