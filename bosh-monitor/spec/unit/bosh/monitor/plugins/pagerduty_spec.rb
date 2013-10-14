require 'spec_helper'

describe Bhm::Plugins::Pagerduty do

  before :each do
    Bhm.logger = Logging.logger(StringIO.new)

    @options = {
      "service_key" => "zbzb",
      "http_proxy"  => "http://nowhere.com:3128"
    }

    @plugin = Bhm::Plugins::Pagerduty.new(@options)
  end

  it "validates options" do
    valid_options = {
      "service_key" => "zb512",
      "http_proxy"  => "http://nowhere.com:3128"
    }

    invalid_options = { # no service key
      "http_proxy"  => "http://nowhere.com:3128"
    }

    Bhm::Plugins::Pagerduty.new(valid_options).validate_options.should be_true
    Bhm::Plugins::Pagerduty.new(invalid_options).validate_options.should be_false
  end

  it "doesn't start if event loop isn't running" do
    @plugin.run.should be_false
  end

  it "sends events to Pagerduty" do
    uri = "https://events.pagerduty.com/generic/2010-04-15/create_event.json"

    alert = Bhm::Events::Base.create!(:alert, alert_payload)
    heartbeat = Bhm::Events::Base.create!(:heartbeat, heartbeat_payload)

    alert_request = {
      :proxy => { :host => "nowhere.com", :port => 3128 },
      :body => Yajl::Encoder.encode({
        :service_key  => "zbzb",
        :event_type   => "trigger",
        :incident_key => alert.id,
        :description  => alert.short_description,
        :details      => alert.to_hash
      })
    }

    heartbeat_request = {
      :proxy => { :host => "nowhere.com", :port => 3128 },
      :body => Yajl::Encoder.encode({
        :service_key  => "zbzb",
        :event_type   => "trigger",
        :incident_key => heartbeat.id,
        :description  => heartbeat.short_description,
        :details      => heartbeat.to_hash
      })
    }

    EM.run do
      @plugin.run

      @plugin.should_receive(:send_http_post_request).with(uri, alert_request)
      @plugin.should_receive(:send_http_post_request).with(uri, heartbeat_request)

      @plugin.process(alert)
      @plugin.process(heartbeat)
      EM.stop
    end
  end

end
