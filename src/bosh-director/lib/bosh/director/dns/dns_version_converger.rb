module Bosh::Director
  class DnsVersionConverger

    ONLY_OUT_OF_DATE_SELECTOR = lambda do |current_version, logger|
      logger.info('Selected strategy: ONLY_OUT_OF_DATE_SELECTOR')
      Models::Instance.inner_join(:vms, vms__instance_id: :instances__id)
        .left_outer_join(:agent_dns_versions, agent_dns_versions__agent_id: :vms__agent_id)
        .select_append(Sequel.expr(:vms__agent_id).as(:agent_id))
        .select_append(Sequel.expr(:instances__id).as(:id))
        .where { Sequel.expr(vms__active: true) }
        .where { ((dns_version < current_version) | Sequel.expr(dns_version: nil)) }
    end

    ALL_INSTANCES_WITH_VMS_SELECTOR = lambda do |_, logger|
      logger.info('Selected strategy: ALL_INSTANCES_WITH_VMS_SELECTOR')
      Models::Instance.inner_join(:vms, vms__instance_id: :instances__id)
        .select_append(Sequel.expr(:instances__id).as(:id))
        .where { Sequel.expr(vms__active: true) }
    end

    def initialize(agent_broadcaster, logger, max_threads, strategy_selector=ONLY_OUT_OF_DATE_SELECTOR)
      @agent_broadcaster = agent_broadcaster
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

      if !instances.empty?
        @agent_broadcaster.sync_dns(instances.all, dns_blob.blobstore_id, dns_blob.sha1, dns_blob.version)
      end

      delete_orphaned_agent_dns_versions

      @logger.info("Finished updating instances with latest dns versions. Elapsed time: #{Time.now-start}")
    end

    private

    def delete_orphaned_agent_dns_versions
      Models::AgentDnsVersion.exclude(
        :agent_dns_versions__agent_id => Models::Vm.select(:vms__agent_id)).delete
    end
  end
end
