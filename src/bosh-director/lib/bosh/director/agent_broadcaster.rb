module Bosh::Director
  class AgentBroadcaster

    BROADCAST_RETRY = 2
    MAX_RETRY_THREAD = 1
    SYNC_DNS_TIMEOUT = 10
    VALID_RESPONSE = 'synced'

    def initialize(sync_dns_timeout=SYNC_DNS_TIMEOUT)
      @logger = Config.logger
      @sync_dns_timeout = sync_dns_timeout
    end

    def delete_arp_entries(vm_cid_to_exclude, ip_addresses)
      @logger.info("deleting arp entries for the following ip addresses: #{ip_addresses}")
      instances = filter_instances(vm_cid_to_exclude)
      broadcast(instances, :delete_arp_entries, ips: ip_addresses)
    end

    def sync_dns(blobstore_id, sha1, version)
      instances = filter_instances(nil)
      timeout = Timeout.new(@sync_dns_timeout)
      @logger.info("Syncing dns for instances #{instances.map(&:agent_id)}")
      broadcast_with_retry(instances, timeout, :sync_dns, blobstore_id, sha1, version)
    end

    def filter_instances(vm_cid_to_exclude)
      Models::Instance
          .exclude(active_vm_id: nil)
          .exclude(compilation: true)
          .all.select {|instance| instance.active_vm.cid != vm_cid_to_exclude }
    end

    private

    def broadcast(instances, method, *args)
      ThreadPool.new(:max_threads => Config.max_threads).wrap do |pool|
        instances.each do |instance|
          pool.process do
            send_agent_request(instance.credentials, instance.agent_id, method, *args)
          end
        end
      end
    end

    def broadcast_with_retry(instances, timeout, method, *args)
      lock = Mutex.new
      (0...BROADCAST_RETRY).each do
        instances_to_retry = []
        instance_to_request_id = {}
        instances.each do |instance|
          instance_to_request_id[instance] = true
          send_agent_request(instance.credentials, instance.agent_id, method, *args) do |response|
            if response['value'] == VALID_RESPONSE
              @logger.info("Got response #{response} from instance #{instance.agent_id}")
            else
              @logger.error("Got error response #{response} from instance #{instance.agent_id}")
            end
            lock.synchronize do
              instance_to_request_id.delete(instance)
            end
          end
        end

        while !timeout.timed_out?
          lock.synchronize do
            return if instance_to_request_id.empty?
          end
          sleep(0.1)
        end

        lock.synchronize do
          if instance_to_request_id.empty?
            return
          else
            instance_to_request_id.each do |instance, _|
              instances_to_retry << instance
            end
            instances = instances_to_retry
            @logger.warn("Unresponsive instances are #{instances.map(&:agent_id)}")
          end
        end
      end
    end

    def send_agent_request(instance_credentials, instance_agent_id, method, *args, &blk)
      agent = AgentClient.with_vm_credentials_and_agent_id(instance_credentials, instance_agent_id)
      agent.send(method, *args, &blk)
    end
  end
end
