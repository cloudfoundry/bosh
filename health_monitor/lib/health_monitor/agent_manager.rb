module Bosh::HealthMonitor

  class AgentManager

    attr_reader :requests_sent, :replies_received

    def initialize
      @agents = { }
      @logger = Bhm.logger
      @agents_by_deployment = { }
      @requests_sent = 0
      @replies_received = 0
    end

    def setup_subscriptions
      # TODO: handle errors
      # TODO: handle missing agent

      Bhm.nats.subscribe("hm.agent.state.reply.*") do |message, reply, subject|
        @replies_received += 1
        agent_id = subject.split('.').last
        @agents[agent_id]["state"] = message
      end

      Bhm.nats.subscribe("hm.agent.alert.*") do |message, reply, subject|
        agent_id = subject.split('.').last
        @logger.info("Received alert from `#{agent_id}': #{message}")
      end
    end

    def agents_count
      @agents.size
    end

    def update_agent(deployment_name, agent_id)
      @agents[agent_id] = { "id" => agent_id } # TODO: make agent a first class object

      @agents_by_deployment[deployment_name] ||= [ ]
      @agents_by_deployment[deployment_name] << agent_id
    end

    def each_agent(&blk)
      @agents_by_deployment.each_pair do |deployment_name, agent_ids|
        agent_ids.each do |agent_id|
          yield @agents[agent_id]
        end
      end
    end

    def update_state(agent)
      # TODO: add timeout
      agent_id      = agent["id"]
      agent_channel = "agent.#{agent_id}"
      # request_id    = UUIDTools::UUID.random_create.to_s

      message = {
        "reply_to" => "hm.agent.state.reply.#{agent_id}",
        "method"   => "get_state",
        "args"     => ""
      }

      Bhm.nats.publish(agent_channel, Yajl::Encoder.encode(message))
      @requests_sent += 1
    end

  end

end
