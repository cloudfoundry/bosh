require 'spec_helper'

describe Bhm::Plugins::ConsulEventForwarder do

  subject{ described_class.new(options)  }
  let(:heartbeat){ make_heartbeat(timestamp: 1320196099) }
  let(:uri){ URI.parse("http://fake-consul-cluster:8500/v1/event/fire/mysql_node_heartbeat?") }
  let(:request){ { :body => heartbeat.to_json } }
  let(:ttl_request){ { :body => heartbeat.to_json } }
  let(:heartbeat_name){ "test_" + heartbeat.job}
  let(:namespace){ "test/" }
  let(:new_port){ "9500" }
  let(:new_protocol){ "https" }
  let(:new_params){ "acl_token=testtoken" }
  let(:heartbeat_name_with_namespace){ "test/test_" + heartbeat.job}
  let(:ttl_pass_uri){ URI.parse("http://fake-consul-cluster:8500/v1/agent/check/pass/#{heartbeat_name}?") }
  let(:ttl_fail_uri){ URI.parse("http://fake-consul-cluster:8500/v1/agent/check/fail/#{heartbeat_name}?") }
  let(:ttl_warn_uri){ URI.parse("http://fake-consul-cluster:8500/v1/agent/check/warn/#{heartbeat_name}?") }
  let(:register_uri){ URI.parse("http://fake-consul-cluster:8500/v1/agent/check/register?") }
  let(:register_uri_with_port){ URI.parse("http://fake-consul-cluster:#{new_port}/v1/agent/check/register?")}
  let(:register_uri_with_protocol){ URI.parse("#{new_protocol}://fake-consul-cluster:8500/v1/agent/check/register?")}
  let(:register_uri_with_params){ URI.parse("http://fake-consul-cluster:8500/v1/agent/check/register?#{new_params}")}
  let(:register_request){ { :body => { "name" => "test_mysql_node", "notes" => "test", "ttl" => "120s"}.to_json } }
  let(:register_request_with_namespace){ { :body => { "name" => "#{namespace}mysql_node", "notes" => "test", "ttl" => "120s"}.to_json } }


  describe "validating the options" do
    context "when we specify host, endpoint and port" do
      let(:options){ { 'host' => "fake-consul-cluster", 'events_api' => '/v1/api', 'port' => 8500 } }
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
      let(:options){ {'host' => 'fake-consul-cluster'} }
      it "is valid" do
        subject.run
        expect(subject.validate_options).to eq(true)
      end
    end

  end


  describe "forwarding event messages to consul" do

    context "without valid options" do
      let(:options){ { 'host' => nil } }
      it "it should not forward events if options are invalid" do
        subject.run
        expect(subject).to_not receive(:send_http_put_request).with(uri, request)
        subject.process(heartbeat)
      end
    end

    context "with valid options" do
      let(:options){ { 'host' => 'fake-consul-cluster', 'events' => true} }
      it "should successully hand the event off to http forwarder" do
        subject.run
        expect(subject).to receive(:send_http_put_request).with(uri, request)
        subject.process(heartbeat)
      end
    end

  end

  describe "sending events to consul" do
    let(:options){ { 'host' => 'fake-consul-cluster', 'events' => true, 'namespace' => 'test_', 'ttl_note' => 'test'} }
    it "should forward events when events are enabled"  do
      subject.run
      expect(subject).to receive(:send_http_put_request).with(uri, request)
      subject.process(heartbeat)
    end
  end

  describe "sending ttl requests to consul" do
    let(:options){ { 'host' => 'fake-consul-cluster', 'ttl' => "120s", 'namespace' => 'test_', 'ttl_note' => 'test'} }


    it "should send a put request to the register endpoint the first time an event is encountered" do
      subject.run
      expect(subject).to receive(:send_http_put_request).with(register_uri, register_request)
      subject.process(heartbeat)
    end

    it "should properly send namespaced job name when namespace used" do
      options.merge!({'namespace' => "test/" })
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
        expect(subject).to receive(:send_http_put_request).with(ttl_pass_uri, ttl_request)
        subject.process(heartbeat)
        EM.stop
      end
    end

    it "should send a fail ttl message when heartbeat is failing" do
      heartbeat.attributes['job_state'] = "failing"
      EM.run do
        subject.run
        subject.process(heartbeat)
        expect(subject).to receive(:send_http_put_request).with(ttl_fail_uri, ttl_request)
        subject.process(heartbeat)
        EM.stop
      end
    end

    it "should send a fail ttl message when heartbeat is unknown" do
      heartbeat.attributes['job_state'] = "failing"

      EM.run do
        subject.run
        subject.process(heartbeat)
        expect(subject).to receive(:send_http_put_request).with(ttl_fail_uri, ttl_request)
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
        expect(subject).to_not receive(:send_http_put_request).with(uri, request)
        subject.process(heartbeat)
      end
    end

    describe "when events are also enabled" do
      let(:options){ { 'host' => 'fake-consul-cluster', 'ttl' => "120s", 'events' => true, 'namespace' => 'test_', 'ttl_note' => 'test'} }

      it "should send ttl and event requests in a single loop" do
        subject.run

        EM.run do
          subject.process(heartbeat)
          EM.stop
        end
        expect(subject).to receive(:send_http_put_request).with(uri, request)
        expect(subject).to receive(:send_http_put_request).with(ttl_pass_uri, ttl_request)
        subject.process(heartbeat)
      end
    end
  end

end
