module NATSSync
  class NatsAuthConfig
    def initialize(vms, director_subject, hm_subject)
      @vms = vms
      @hm_subject = hm_subject
      @director_subject = director_subject
      @config = { 'authorization' =>
                    { 'users' => [] } }
    end

    def director_user
      {
        'user' => @director_subject,
        'permissions' => {
          'publish' => %w[agent.* agent.inbox.> hm.director.alert],
          'subscribe' => ['director.>'],
        },
      }
    end

    def hm_user
      {
        'user' => @hm_subject,
        'permissions' => {
          'publish' => [],
          'subscribe' => %w[hm.agent.heartbeat.* hm.agent.alert.* hm.agent.shutdown.* hm.director.alert],
        },
      }
    end

    def agent_user(agent_id, cn)
      {
        'user' => "C=USA, O=Cloud Foundry, CN=#{cn}.agent.bosh-internal",
        'permissions' => {
          'publish' => [
            "hm.agent.heartbeat.#{agent_id}",
            "hm.agent.alert.#{agent_id}",
            "hm.agent.shutdown.#{agent_id}",
            "director.*.#{agent_id}.*",
            "director.agent.disk.*.#{agent_id}",
          ],
          "subscribe": ["agent.#{agent_id}", "agent.inbox.#{agent_id}.>"],
        },
      }
    end

    def create_config
      @config['authorization']['users'] << director_user unless @director_subject.nil?
      @config['authorization']['users'] << hm_user unless @hm_subject.nil?
      @vms.each do |vm|
        agent_id = vm['agent_id']
        if !vm['permanent_nats_credentials']
          @config['authorization']['users'] << agent_user(agent_id, agent_id + '.bootstrap')
        end
        @config['authorization']['users'] << agent_user(agent_id, agent_id)
      end
      @config
    end
  end
end
