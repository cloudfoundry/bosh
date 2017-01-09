module Bosh::Director
  class DnsVersionConverger

    def initialize(logger, max_threads)
      @logger = logger
      @max_threads = max_threads
    end

    def update_instances_with_stale_dns_records
      start = Time.now

      dns_blob = Models::LocalDnsBlob.latest

      if dns_blob.nil?
        @logger.info("No dns record sets detected, no instances will be updated.")
        return
      end

      instances = stale_instances(dns_blob.id)

      @logger.info("Detected #{instances.count} instances with outdated dns versions. Current dns version is #{dns_blob.id}")

      ThreadPool.new(max_threads: Config.max_threads, logger: @logger).wrap do |pool|
        instances.each do |instance|
        @logger.info("Updating instance '#{instance}' with agent id '#{instance.agent_id}' to dns version '#{dns_blob.id}'")
          pool.process do
            update_dns_for_instance(dns_blob, instance)
          end
        end
      end

      delete_orphaned_agent_dns_versions

      @logger.info("Finished updating instances with latest dns versions. Elapsed time: #{Time.now-start}")
    end

    private

    def stale_instances(current_version)
      Models::Instance.left_outer_join(:agent_dns_versions, agent_dns_versions__agent_id: :instances__agent_id)
        .select_append(Sequel.expr(:instances__agent_id).as(:agent_id))
        .where { ((dns_version < current_version) | Sequel.expr(dns_version: nil)) & Sequel.~(vm_cid: nil) }
    end

    def update_dns_for_instance(dns_blob, instance)
      agent_client = AgentClient.with_vm_credentials_and_agent_id(instance.credentials, instance.agent_id)

      timeout = Timeout.new(3)
      response_received = false

      nats_request_id = agent_client.sync_dns(dns_blob.blobstore_id, dns_blob.sha1, dns_blob.id) do |response|
        if response['value'] == 'synced'
          Models::AgentDnsVersion.find_or_create(agent_id: instance.agent_id)
            .update(dns_version: dns_blob.id)
          @logger.info("Successfully updated instance '#{instance}' dns to version #{dns_blob.id}. agent sync_dns response: '#{response}'")
        else
          @logger.info("Failed to update instance '#{instance}' dns to version #{dns_blob.id}. agent sync_dns response: '#{response}'")
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

    def delete_orphaned_agent_dns_versions
      Models::AgentDnsVersion.exclude(
        :agent_dns_versions__agent_id => Models::Instance.select(:instances__agent_id)).delete
    end
  end
end

