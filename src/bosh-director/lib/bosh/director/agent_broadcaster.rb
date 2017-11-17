module Bosh::Director
  class AgentBroadcaster

    DEFAULT_BROADCAST_TIMEOUT = 10
    VALID_SYNC_DNS_RESPONSE = 'synced'

    def initialize(broadcast_timeout=DEFAULT_BROADCAST_TIMEOUT)
      @logger = Config.logger
      @broadcast_timeout = broadcast_timeout
      @reactor_loop = EmReactorLoop.new
    end

    def delete_arp_entries(vm_cid_to_exclude, ip_addresses)
      @logger.info("deleting arp entries for the following ip addresses: #{ip_addresses}")
      instances = filter_instances(vm_cid_to_exclude)
      instances.each do |instance|
        agent_client(instance.agent_id).delete_arp_entries(ips: ip_addresses)
      end
    end

    def sync_dns(instances, blobstore_id, sha1, version)
      @logger.info("agent_broadcaster: sync_dns: sending to #{instances.length} agents #{instances.map(&:agent_id)}")

      lock = Mutex.new

      num_successful = 0
      num_unresponsive = 0
      num_failed = 0
      start_time = Time.now

      instance_to_request_id = {}
      pending = Set.new

      instances.each do |instance|
        pending.add(instance)
        instance_to_request_id[instance] = agent_client(instance.agent_id).sync_dns(blobstore_id, sha1, version) do |response|
          valid_response = (response['value'] == VALID_SYNC_DNS_RESPONSE)

          if valid_response
            updated_rows = Models::AgentDnsVersion.where(agent_id: instance.agent_id).update(dns_version: version)

            if updated_rows == 0
              begin
                Models::AgentDnsVersion.create(agent_id: instance.agent_id, dns_version: version)
              rescue Sequel::UniqueConstraintViolation
                Models::AgentDnsVersion.where(agent_id: instance.agent_id).update(dns_version: version)
              end
            end
          end

          lock.synchronize do
            if valid_response
              num_successful += 1
            else
              num_failed += 1
              @logger.error("agent_broadcaster: sync_dns[#{instance.agent_id}]: received unexpected response #{response}")
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
          agent_client = agent_client(instance.agent_id)
          agent_client.cancel_sync_dns(instance_to_request_id[instance])

          lock.synchronize do
            num_unresponsive += 1
          end

          unresponsive_agents << instance.agent_id
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
      Models::Instance
        .inner_join(:vms, Sequel.qualify('vms', 'instance_id') => Sequel.qualify('instances','id'))
        .select_append(Sequel.expr(Sequel.qualify('instances','id')).as(:id))
        .where { Sequel.expr(Sequel.qualify('vms','active') => true) }
        .exclude { Sequel.expr(Sequel.qualify('vms','cid') => vm_cid_to_exclude) }
        .where(compilation: false)
        .all
    end

    private

    def agent_client(instance_agent_id)
      AgentClient.with_agent_id(instance_agent_id)
    end
  end

  class EmReactorLoop
    def queue(&blk)
      blk.call
    end
  end
end
