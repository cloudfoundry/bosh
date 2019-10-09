module Bosh::Director
  class AgentBroadcaster
    DEFAULT_BROADCAST_TIMEOUT = 10
    VALID_SYNC_DNS_RESPONSE = 'synced'.freeze

    def initialize(broadcast_timeout = DEFAULT_BROADCAST_TIMEOUT)
      @logger = Config.logger
      @broadcast_timeout = broadcast_timeout
      @reactor_loop = EmReactorLoop.new
    end

    def delete_arp_entries(vm_cid_to_exclude, ip_addresses)
      @logger.info("deleting arp entries for the following ip addresses: #{ip_addresses}")
      instances = filter_instances(vm_cid_to_exclude)
      instances.each do |instance|
        agent_client(agent_id_for_instance(instance), instance.name).delete_arp_entries(ips: ip_addresses)
      end
    end

    def sync_dns(instances, blobstore_id, sha1, version)
      agent_ids = instances.map { |instance| agent_id_for_instance(instance) }
      @logger.info("agent_broadcaster: sync_dns: sending to #{instances.length} agents #{agent_ids}")

      lock = Mutex.new

      num_successful = 0
      num_unresponsive = 0
      num_failed = 0
      start_time = Time.now

      instance_to_request_id = {}
      pending = Set.new

      instances.each do |instance|
        pending.add(instance)
        agent_id = agent_id_for_instance(instance)
        instance_to_request_id[instance] = perform_sync(agent_id, instance, blobstore_id, sha1, version) do |response|
          valid_response = (response['value'] == VALID_SYNC_DNS_RESPONSE)

          if valid_response
            updated_rows = Models::AgentDnsVersion.where(agent_id: agent_id).update(dns_version: version)

            if updated_rows == 0
              begin
                Models::AgentDnsVersion.create(agent_id: agent_id, dns_version: version)
              rescue Sequel::UniqueConstraintViolation
                Models::AgentDnsVersion.where(agent_id: agent_id).update(dns_version: version)
              end
            end
          end

          lock.synchronize do
            if valid_response
              num_successful += 1
            else
              num_failed += 1
              @logger.error("agent_broadcaster: sync_dns[#{agent_id}]: received unexpected response #{response}")
            end
            pending.delete(instance)
          end
        end
      end

      @reactor_loop.queue do
        # start timeout after current
        # 10s? what if we have 1000 vms?
        timeout = Timeout.new(@broadcast_timeout)

        pending_reqs = true
        while pending_reqs && !timeout.timed_out?
          sleep(0.1)
          lock.synchronize do
            pending_reqs = pending.any?
          end
        end

        pending_clone = []
        lock.synchronize do
          pending_clone = pending.clone
        end

        unresponsive_agents = []
        pending_clone.each do |instance|
          agent_id = agent_id_for_instance(instance)
          agent_client = agent_client(agent_id, instance.name)
          agent_client.cancel_sync_dns(instance_to_request_id[instance])

          lock.synchronize do
            num_unresponsive += 1
          end

          unresponsive_agents << agent_id
        end
        if num_unresponsive > 0
          @logger.warn("agent_broadcaster: sync_dns: no response received for #{num_unresponsive} agent(s): [#{unresponsive_agents.join(', ')}]")
        end

        elapsed_time = ((Time.now - start_time) * 1000).ceil
        lock.synchronize do
          @logger.info("agent_broadcaster: sync_dns: attempted #{instances.length} agents in #{elapsed_time}ms (#{num_successful} successful, #{num_failed} failed, #{num_unresponsive} unresponsive)")
        end
      end
    end

    def filter_instances(vm_cid_to_exclude)
      instances_from_db = Models::Instance.where(compilation: false).eager(:vms).all

      instances_from_db.select do |instance|
        instance.vms.any? do |vm|
          vm.active && vm.cid != vm_cid_to_exclude
        end
      end
    end

    private

    def agent_client(instance_agent_id, instance_name)
      AgentClient.with_agent_id(instance_agent_id, instance_name)
    end

    def agent_id_for_instance(instance)
      cached_vm = instance.vms.find(&:active)
      cached_vm.nil? ? nil : cached_vm.agent_id
    end

    def perform_sync(agent_id, instance, blobstore_id, digest, version, &blk)
      if can_use_signed_urls(instance)
        signed_url = blobstore_client.sign(blobstore_id)
        agent_client(agent_id, instance.name).sync_dns_with_signed_url(signed_url, digest, version, &blk)
      else
        agent_client(agent_id, instance.name).sync_dns(blobstore_id, digest, version, &blk)
      end
    end

    def can_use_signed_urls(instance)
      blobstore_client.signing_enabled? && instance.active_vm.stemcell_api_version >= 3
    end

    def blobstore_client
      @blobstore_client ||= App.instance.blobstores.blobstore
    end
  end

  class EmReactorLoop
    def queue
      yield
    end
  end
end
