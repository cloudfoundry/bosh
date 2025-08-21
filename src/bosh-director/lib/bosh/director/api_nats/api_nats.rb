module Bosh::Director
  module ApiNats
    extend ValidationHelper

    USERNAME = "bosh-agent".freeze

    def setup_events
      disk_controller = DynamicDiskController.new

      Config.nats_rpc.nats.subscribe('director.agent.disk.provide.*') do |payload, reply, subject|
        payload = parse_payload(payload)
        disk_controller.handle_provide_disk_request(parse_agent_id(subject), reply, payload)
      rescue => e
        Config.nats_rpc.send_message(reply, { "error" => e.message })
        raise
      end

      Config.nats_rpc.nats.subscribe('director.agent.disk.detach.*') do |payload, reply, subject|
        payload = parse_payload(payload)
        disk_controller.handle_detach_disk_request(parse_agent_id(subject), reply, payload)
      rescue => e
        Config.nats_rpc.send_message(reply, { "error" => e.message })
        raise
      end

      Config.nats_rpc.nats.subscribe('director.agent.disk.delete.*') do |payload, reply, _subject|
        payload = parse_payload(payload)
        disk_controller.handle_delete_disk_request(reply, payload)
      rescue => e
        Config.nats_rpc.send_message(reply, { "error" => e.message })
        raise
      end
    end

    private

    def parse_agent_id(subject)
      # subject: director.agent.disk.provide.agent_id
      agent_id = subject.split('.', 5).last
      raise 'Subject must include agent_id' if agent_id.empty?
      return agent_id
    end

    def parse_payload(payload)
      case payload
      when String
        return JSON.parse(payload)
      when Hash
        return payload
      else
        raise "Payload must be a JSON string or hash"
      end
    end
  end
end