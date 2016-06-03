module Bosh::Director
  class AgentBroadcaster
    def delete_arp_entries(vm_cid_to_exclude, ip_addresses)
      instances = filter_instances(vm_cid_to_exclude)
      broadcast(instances, :delete_arp_entries, ips: ip_addresses)
    end

    def sync_dns(blobstore_id, sha1)
      instances = filter_instances(nil)
      broadcast(instances, :sync_dns, blobstore_id, sha1)
    end

    def broadcast(instances, method, *args)
      ThreadPool.new(:max_threads => Config.max_threads).wrap do |pool|
        instances.each do |instance|
          pool.process do
            agent = AgentClient.with_vm_credentials_and_agent_id(instance.credentials, instance.agent_id)
            agent.send(method, *args)
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
