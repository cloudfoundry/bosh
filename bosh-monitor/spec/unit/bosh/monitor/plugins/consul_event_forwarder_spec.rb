require 'spec_helper'

describe Bhm::Plugins::ConsulEventForwarder do
  WebMock.allow_net_connect!

  subject{ described_class.new(options)  }
  let(:heartbeat){ make_heartbeat(timestamp: 1320196099) }
  let(:alert){ make_alert }
  let(:alert_uri){ URI.parse("http://fake-consul-cluster:8500/v1/event/fire/#{namespace}test_alert?") }
  let(:heartbeat_alert_uri){ URI.parse("http://fake-consul-cluster:8500/v1/event/fire/#{heartbeat_name}?") }
  let(:event_request) {{ :body => alert.to_json }}
  let(:heartbeat_request){ { :body => simplified_heartbeat.to_json } }
  let(:heartbeat_name){ namespace + heartbeat.job }
  let(:namespace){ "ns_" }
  let(:new_port){ "9500" }
  let(:new_protocol){ "https" }
  let(:new_params){ "acl_token=testtoken" }
  let(:agent_base_url){ "http://fake-consul-cluster:8500/v1/agent/check/" }
  let(:ttl_pass_uri){ URI.parse( agent_base_url + "pass/#{heartbeat_name}?") }
  let(:ttl_fail_uri){ URI.parse( agent_base_url + "fail/#{heartbeat_name}?") }
  let(:ttl_warn_uri){ URI.parse( agent_base_url + "warn/#{heartbeat_name}?") }
  let(:register_uri){ URI.parse( agent_base_url + "register?") }
  let(:register_uri_with_port){ URI.parse("http://fake-consul-cluster:#{new_port}/v1/agent/check/register?")}
  let(:register_uri_with_protocol){ URI.parse("#{new_protocol}://fake-consul-cluster:8500/v1/agent/check/register?")}
  let(:register_uri_with_params){ URI.parse("http://fake-consul-cluster:8500/v1/agent/check/register?#{new_params}")}
  let(:register_request){ { :body => { "name" => "#{namespace}mysql_node", "notes" => "test", "ttl" => "120s"}.to_json } }
  let(:register_request_with_namespace){ { :body => { "name" => "#{namespace}mysql_node", "notes" => "test", "ttl" => "120s"}.to_json } }

  #we send a simplified version of a heartbeat to consul when sending as an event because consul has a 512byte limit for events
  let(:simplified_heartbeat){ {
    :agent => "deadbeef",
    :name => "mysql_node/0",
    :state => "running",
    :data => { "cpu" => [22.3,23.4,33.22],
               "dsk" => {
                 "eph" => [33,74],
                 "sys" => [74,68]},
                 "ld"  => [0.2,0.3,0.6],
                 "mem" => [32.2,512031],
                 "swp" => [32.6,231312]
              }
     }
  }


  describe "validating the options" do
    context "when we specify host, endpoint and port" do
      let(:options){ { 'host' => "fake-consul-cluster", 'protocol' => 'http', 'events_api' => '/v1/api', 'port' => 8500 } }
      it "is valid" do
        subject.run
        expect(subject.validate_options).to eq(true)
      end
    end

    context "when we omit the host" do
      let(:options){ {'host' => nil} }
      it "is not valid" do
        subject.run
        expect(subject.validate_options).to eq(false)
      end
    end

    context "when we omit the enpoint and port" do
      let(:options){ {'host' => 'fake-consul-cluster', 'protocol' => 'https', 'port' => 8500} }
      it "is valid" do
        subject.run
        expect(subject.validate_options).to eq(true)
      end
    end

  end


  describe "forwarding alert messages to consul" do

    context "without valid options" do
      let(:options){ { 'host' => nil } }
      it "it should not forward events if options are invalid" do
        subject.run
        expect(subject).to_not receive(:send_http_put_request).with(alert_uri, event_request)
        subject.process(alert)
      end
    end

    context "with valid options" do
      let(:options){ { 'host' => 'fake-consul-cluster', 'namespace' => namespace, 'events' => true, 'protocol' => 'http', 'port' => 8500} }
      it "should successully hand the alert off to http forwarder" do
        subject.run
        expect(subject).to receive(:send_http_put_request).with(alert_uri, event_request)
        subject.process(alert)
      end
    end

  end

  describe "sending alerts to consul" do
    let(:options){ { 'host' => 'fake-consul-cluster', 'events' => true, 'namespace' => namespace, 'protocol' => 'http', 'port' => 8500} }
    it "should forward events when events are enabled"  do
      subject.run
      expect(subject).to receive(:send_http_put_request).with(alert_uri, event_request)
      subject.process(alert)
    end
  end

  describe "sending heartbeats as ttl requests to consul" do
    let(:options){ { 'host' => 'fake-consul-cluster', 'ttl' => "120s", 'namespace' => namespace, 'ttl_note' => 'test', 'protocol' => 'http', 'port' => 8500} }

    it "should send a put request to the register endpoint the first time an event is encountered" do
      subject.run
      expect(subject).to receive(:send_http_put_request).with(register_uri, register_request)
      subject.process(heartbeat)
    end

    it "should properly send namespaced job name when namespace used" do
      options.merge!({'namespace' => namespace })
      subject.run
      expect(subject).to receive(:send_http_put_request).with(register_uri, register_request_with_namespace)
      subject.process(heartbeat)
    end

    it "should properly change the required port when a port is passed in options" do
      options.merge!({ 'port' => new_port })
      subject.run
      expect(subject).to receive(:send_http_put_request).with(register_uri_with_port, register_request)
      subject.process(heartbeat)
    end

    it "should properly change the protocol when a port is passed in options" do
      options.merge!({ 'protocol' => new_protocol })
      subject.run
      expect(subject).to receive(:send_http_put_request).with(register_uri_with_protocol, register_request)
      subject.process(heartbeat)
    end

    it "should properly provide params when params are passed in options" do
      options.merge!({ 'params' => new_params })
      subject.run
      expect(subject).to receive(:send_http_put_request).with(register_uri_with_params, register_request)
      subject.process(heartbeat)
    end

    it "should send a put request to the ttl endpoint the second time an event is encountered" do
      EM.run do
        subject.run
        subject.process(heartbeat)
        expect(subject).to receive(:send_http_put_request).with(ttl_pass_uri, heartbeat_request)
        subject.process(heartbeat)
        EM.stop
      end
    end

    it "should send a fail ttl message when heartbeat is failing" do
      heartbeat.attributes['job_state'] = "failing"
      EM.run do
        subject.run
        subject.process(heartbeat)
        expect(subject).to receive(:send_http_put_request).with(ttl_fail_uri, heartbeat_request)
        subject.process(heartbeat)
        EM.stop
      end
    end

    it "should send a fail ttl message when heartbeat is unknown" do
      heartbeat.attributes['job_state'] = "failing"

      EM.run do
        subject.run
        subject.process(heartbeat)
        expect(subject).to receive(:send_http_put_request).with(ttl_fail_uri, heartbeat_request)
        subject.process(heartbeat)
        EM.stop
      end
    end

    it "should not send a registration request if an event is already registered" do
      subject.run
      EM.run do
        subject.process(heartbeat)
        EM.stop
      end

      expect(subject).to_not receive(:send_http_put_request).with(register_uri, register_request)
      subject.process(heartbeat)
    end

    describe "when events are not enabled" do
      let(:options){ { 'host' => 'fake-consul-cluster', 'events' => false } }
      it "should not forward events" do
        subject.run

        EM.run do
          subject.process(heartbeat)
          EM.stop
        end
        expect(subject).to_not receive(:send_http_put_request).with(alert_uri, event_request)
        subject.process(alert)
      end
    end

    describe "when events are also enabled" do
      let(:options){ { 'host' => 'fake-consul-cluster', 'ttl' => "120s", 'events' => true, 'namespace' => namespace, 'ttl_note' => 'test', 'protocol' => 'http', 'port' => 8500} }

      it "should not send ttl and event requests for same event" do
        subject.run

        EM.run do
          subject.process(heartbeat)
          EM.stop
        end
        expect(subject).to_not receive(:send_http_put_request).with(alert_uri, event_request)
        expect(subject).to receive(:send_http_put_request).with(ttl_pass_uri, heartbeat_request)
        subject.process(heartbeat)
      end

      describe "When send heartbeats_as_alerts is enabled" do
        it "should send both ttl and event request in the same loop " do
          options.merge!({'heartbeats_as_alerts' => true})
          subject.run

          EM.run do
            subject.process(heartbeat)
            EM.stop
          end
          expect(subject).to receive(:send_http_put_request).with(heartbeat_alert_uri, heartbeat_request)
          expect(subject).to receive(:send_http_put_request).with(ttl_pass_uri, heartbeat_request)
          subject.process(heartbeat)
        end
      end
    end
  end

end
