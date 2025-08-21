module Bosh::Director
  module ApiNats
    class DynamicDiskController
      include ValidationHelper

      USERNAME = "bosh-agent".freeze

      def handle_provide_disk_request(agent_id, reply, payload)
        disk_name = safe_property(payload, "disk_name", class: String, min_length: 1)
        disk_pool_name = safe_property(payload, "disk_pool_name", class: String, min_length: 1)
        disk_size = safe_property(payload, "disk_size", class: Integer, min: 1)
        metadata = safe_property(payload, "metadata", class: Hash, optional: true)
        
        JobQueue.new.enqueue(
          USERNAME,
          Jobs::DynamicDisks::ProvideDynamicDisk,
          'provide dynamic disk',
          [agent_id, reply, disk_name, disk_pool_name, disk_size, metadata]
        )
      rescue => e
        Config.nats_rpc.send_message(reply, { "error" => e.message })
        raise
      end

      def handle_detach_disk_request(agent_id, reply, payload)
        disk_name = safe_property(payload, "disk_name", class: String, min_length: 1)

        JobQueue.new.enqueue(
          USERNAME,
          Jobs::DynamicDisks::DetachDynamicDisk,
          'detach dynamic disk',
          [reply, disk_name]
        )
      rescue => e
        Config.nats_rpc.send_message(reply, { "error" => e.message })
        raise
      end

      def handle_delete_disk_request(reply, payload)
        disk_name = safe_property(payload, "disk_name", class: String, min_length: 1)

        JobQueue.new.enqueue(
          USERNAME,
          Jobs::DynamicDisks::DeleteDynamicDisk,
          'delete dynamic disk',
          [reply, disk_name]
        )
      rescue => e
        Config.nats_rpc.send_message(reply, { "error" => e.message })
        raise
      end
    end
  end
end