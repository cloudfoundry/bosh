module Bosh::Agent
  class Alert

    attr_reader :alert_id, :service, :event, :action, :date

    def self.register(alert_id, service, event, action, date)
      new(alert_id, service, event, action, date).register
    end

    def initialize(alert_id, service, event, action, date)
      @nats     = Config.nats
      @agent_id = Config.agent_id

      @alert_id = alert_id
      @service  = service
      @event    = event
      @action   = action
      @date     = date
    end

    def register
      payload = {
        :alert_id => alert_id,
        :service  => service,
        :event    => event,
        :action   => action,
        :date     => date
      }

      @nats.publish("hm.agent.alert.#{@agent_id}", Yajl::Encoder.encode(payload))
    end

  end
end
