module Bosh::Director
  class AgentBroadcaster

    DEFAULT_BROADCAST_TIMEOUT = 10
    VALID_SYNC_DNS_RESPONSE = 'synced'

    def initialize(broadcast_timeout=DEFAULT_BROADCAST_TIMEOUT)
      @logger = Config.logger
      @broadcast_timeout = broadcast_timeout
    end

    def delete_arp_entries(vm_cid_to_exclude, ip_addresses)
      @logger.info("deleting arp entries for the following ip addresses: #{ip_addresses}")
      instances = filter_instances(vm_cid_to_exclude)
      broadcast(instances, :delete_arp_entries, ips: ip_addresses)
    end

    def sync_dns(instances, blobstore_id, sha1, version)
      @logger.info("agent_broadcaster: sync_dns: sending to #{instances.length} agents #{instances.map(&:agent_id)}")
      num_successful = 0
      num_unresponsive = 0
      num_failed = 0
      start_time = Time.now
      broadcast_and_wait_for_response(instances, :sync_dns, [blobstore_id, sha1, version]) do |agent_id, response|
        if response['value'] == 'unresponsive'
          num_unresponsive += 1
          agent_client(response['credentials'], agent_id).cancel_sync_dns(response['request_id'])

          @logger.warn("agent_broadcaster: sync_dns[#{agent_id}]: no response received")
        elsif response['value'] == VALID_SYNC_DNS_RESPONSE
          num_successful += 1
          Models::AgentDnsVersion.find_or_create(agent_id: agent_id).update(dns_version: version)
        else
          num_failed += 1
          @logger.error("agent_broadcaster: sync_dns[#{agent_id}]: received unexpected response #{response}")
        end
      end
      elapsed_time = ((Time.now - start_time) * 1000).ceil

      @logger.info("agent_broadcaster: sync_dns: attempted #{instances.length} agents in #{elapsed_time}ms (#{num_successful} successful, #{num_failed} failed, #{num_unresponsive} unresponsive)")
    end

    def filter_instances(vm_cid_to_exclude)
      Models::Instance
          .exclude(compilation: true)
          .all.select {|instance| !instance.active_vm.nil? && (instance.vm_cid != vm_cid_to_exclude) }
    end

    private

    def broadcast(instances, method, *args)
      instances.each do |instance|
        send_agent_request(instance.credentials, instance.agent_id, method, *args)
      end
    end

    def broadcast_and_wait_for_response(instances, method, args_list, &blk)
      lock = Mutex.new

      instance_to_request_id = {}
      instances.each do |instance|
        instance_to_request_id[instance] = true
        send_agent_request(instance.credentials, instance.agent_id, method, *args_list) do |response|
          lock.synchronize do
            blk.call(instance.agent_id, response)

            instance_to_request_id.delete(instance)
          end
        end
      end

      timeout = Timeout.new(@broadcast_timeout)

      while !timeout.timed_out?
        lock.synchronize do
          return if instance_to_request_id.empty?
        end
        sleep(0.1)
      end

      unresponsive_instances = []
      lock.synchronize do
        if instance_to_request_id.empty?
          return
        else
          instance_to_request_id.each do |instance, _|
            unresponsive_instances << instance
          end
        end

        unresponsive_instances.each do |instance|
          blk.call(instance.agent_id, {
            'value' => 'unresponsive',
            'credentials' => instance.credentials,
            'request_id' => instance_to_request_id[instance],
          })
        end
      end
    end

    def send_agent_request(instance_credentials, instance_agent_id, method, *args, &blk)
      agent_client(instance_credentials, instance_agent_id).send(method, *args, &blk)
    end

    def agent_client(instance_credentials, instance_agent_id)
      AgentClient.with_vm_credentials_and_agent_id(instance_credentials, instance_agent_id)
    end
  end
end
