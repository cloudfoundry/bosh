module Bosh::Director
  class AgentDnsUpdater
    def initialize(logger)
      @logger = logger
    end

    def update_dns_for_instance(dns_blob, instance)
      agent_client = AgentClient.with_vm_credentials_and_agent_id(instance.credentials, instance.agent_id)

      timeout = Timeout.new(3)
      response_received = false

      nats_request_id = agent_client.sync_dns(dns_blob.blobstore_id, dns_blob.sha1, dns_blob.version) do |response|
        if response['value'] == 'synced'
          Models::AgentDnsVersion.find_or_create(agent_id: instance.agent_id)
            .update(dns_version: dns_blob.version)
          @logger.info("Successfully updated instance '#{instance}' with agent id '#{instance.agent_id}' to dns version #{dns_blob.version}. agent sync_dns response: '#{response}'")
        else
          @logger.info("Failed to update instance '#{instance}' with agent id '#{instance.agent_id}' to dns version #{dns_blob.version}. agent sync_dns response: '#{response}'")
        end
        response_received = true
      end

      until response_received
        sleep(0.1)
        if timeout.timed_out?
          agent_client.cancel_sync_dns(nats_request_id)
          return
        end
      end
    end
  end
end
