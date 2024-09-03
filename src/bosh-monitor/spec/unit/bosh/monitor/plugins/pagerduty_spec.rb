require 'spec_helper'

describe Bhm::Plugins::Pagerduty do
  before do
    @options = {
      'service_key' => 'zbzb',
      'http_proxy' => 'http://nowhere.com:3128',
    }

    @plugin = Bhm::Plugins::Pagerduty.new(@options)
  end

  it 'validates options' do
    valid_options = {
      'service_key' => 'zb512',
      'http_proxy' => 'http://nowhere.com:3128',
    }

    invalid_options = { # no service key
      'http_proxy' => 'http://nowhere.com:3128',
    }

    expect(Bhm::Plugins::Pagerduty.new(valid_options).validate_options).to be(true)
    expect(Bhm::Plugins::Pagerduty.new(invalid_options).validate_options).to be(false)
  end

  it "doesn't start if event loop isn't running" do
    expect(@plugin.run).to be(false)
  end

  it 'sends events to Pagerduty' do
    uri = 'https://events.pagerduty.com/generic/2010-04-15/create_event.json'

    alert = Bhm::Events::Base.create!(:alert, alert_payload)
    heartbeat = Bhm::Events::Base.create!(:heartbeat, heartbeat_payload)

    alert_request = {
      proxy: 'http://nowhere.com:3128',
      body: JSON.dump(
        service_key: 'zbzb',
        event_type: 'trigger',
        incident_key: alert.id,
        description: alert.short_description,
        details: alert.to_hash,
      ),
    }

    heartbeat_request = {
      proxy: 'http://nowhere.com:3128',
      body: JSON.dump(
        service_key: 'zbzb',
        event_type: 'trigger',
        incident_key: heartbeat.id,
        description: heartbeat.short_description,
        details: heartbeat.to_hash,
      ),
    }

    Sync do
      @plugin.run

      expect(@plugin).to receive(:send_http_post_request_synchronous_with_tls_verify_peer).with(uri, alert_request)
      expect(@plugin).to receive(:send_http_post_request_synchronous_with_tls_verify_peer).with(uri, heartbeat_request)

      @plugin.process(alert)
      @plugin.process(heartbeat)
    end
  end
end
