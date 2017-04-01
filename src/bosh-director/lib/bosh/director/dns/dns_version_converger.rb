module Bosh::Director
  class DnsVersionConverger

    ONLY_OUT_OF_DATE_SELECTOR = lambda do |current_version, logger|
      logger.info('Selected strategy: ONLY_OUT_OF_DATE_SELECTOR')
      Models::Instance.inner_join(:vms, vms__id: :instances__active_vm_id)
        .left_outer_join(:agent_dns_versions, agent_dns_versions__agent_id: :vms__agent_id)
        .select_append(Sequel.expr(:vms__agent_id).as(:agent_id))
        .where { ((dns_version < current_version) | Sequel.expr(dns_version: nil)) }
    end

    ALL_INSTANCES_WITH_VMS_SELECTOR = lambda do |current_version, logger|
      logger.info('Selected strategy: ALL_INSTANCES_WITH_VMS_SELECTOR')
      Models::Instance.exclude(active_vm_id: nil)
    end

    def initialize(logger, max_threads, strategy_selector=ONLY_OUT_OF_DATE_SELECTOR)
      @logger = logger
      @max_threads = max_threads
      @instances_strategy = strategy_selector
    end

    def update_instances_based_on_strategy
      start = Time.now

      dns_blob = Models::LocalDnsBlob.latest

      if dns_blob.nil?
        @logger.info("No dns record sets detected, no instances will be updated.")
        return
      end

      instances = @instances_strategy.call(dns_blob.version, @logger)

      @logger.info("Detected #{instances.count} instances with outdated dns versions. Current dns version is #{dns_blob.version}")

      ThreadPool.new(max_threads: Config.max_threads, logger: @logger).wrap do |pool|
        instances.each do |instance|
          @logger.info("Updating instance '#{instance}' with agent id '#{instance.agent_id}' to dns version '#{dns_blob.version}'")
          pool.process do
            update_dns_for_instance(dns_blob, instance)
          end
        end
      end

      delete_orphaned_agent_dns_versions

      @logger.info("Finished updating instances with latest dns versions. Elapsed time: #{Time.now-start}")
    end

    private

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

    def delete_orphaned_agent_dns_versions
      Models::AgentDnsVersion.exclude(
        :agent_dns_versions__agent_id => Models::Vm.select(:vms__agent_id)).delete
    end
  end
end

