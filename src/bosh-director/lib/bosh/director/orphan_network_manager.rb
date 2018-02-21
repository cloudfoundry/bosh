module Bosh::Director
  class OrphanNetworkManager
    def initialize(logger)
      @logger = logger
      @transactor = Transactor.new
    end

    def orphan_network(network)
      @transactor.retryable_transaction(Bosh::Director::Config.db) do
        begin
          parent_id = add_event('orphan', network.name, 'network')
          network.orphaned = true
          network.orphaned_at = Time.now
          @logger.info("Orphaning network: '#{network.name}'")
          network.save
        rescue StandardError => e
          raise e
        ensure
          add_event(
            'orphan',
            network.name,
            'network',
            parent_id,
            e,
          )
        end
      end
    end

    def unorphan_network(network)
      @transactor.retryable_transaction(Bosh::Director::Config.db) do
        network.orphaned = false
        network.save
      end
    end

    # returns a list of orphaned networks
    def list_orphan_networks
      Models::Network.where(orphaned: true).map do |network|
        {
          'name' => network.name,
          'type' => network.type,
          'created_at' => network.created_at.to_s,
          'orphaned_at' => network.orphaned_at.to_s,
        }
      end
    end

    def delete_network(network)
      @logger.info("Deleting orphan network: #{network.name}")
      orphan_network = Models::Network.where(name: network.name).first
      if orphan_network
        orphan_network.subnets.each do |subnet|
          delete_subnet(subnet)
        end
        network.destroy
      else
        @logger.debug("Subnet not found: #{network_cid}")
      end
    end

    def delete_subnet(subnet)
      cid = subnet.cid
      parent_id = add_event('delete', cid, 'subnet')
      @logger.info("Deleting orphan subnet: #{cid}")
      cloud = CloudFactory.create.get(subnet.cpi)
      cloud.delete_network(cid)
      subnet.destroy
    # TODO: change exception to a specific cloud error
    rescue StandardError => e
      @logger.debug("Cannot delete subnet in IaaS: #{subnet.cid}")
      subnet.destroy
    ensure
      add_event('delete', cid, 'subnet', parent_id, e)
    end

    private

    def add_event(action, object_name, object_type, _parent_id = nil, error = nil)
      event = Config.current_job.event_manager.create_event(
        user:        Config.current_job.username,
        action:      action,
        object_type: object_type,
        object_name: object_name,
        task:        Config.current_job.task_id,
        error:       error,
      )
      event.id
    end
  end
end
