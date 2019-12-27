require_relative '../../../../spec_helper'

describe Bhm::Plugins::ConsulEventForwarder do
  WebMock.allow_net_connect!

  subject { described_class.new(options) }
  let(:heartbeat) { make_heartbeat(timestamp: 1320196099) }
  let(:alert) { make_alert }
  let(:alert_uri) { URI.parse("http://fake-consul-cluster:8500/v1/event/fire/#{namespace}test_alert?") }
  let(:heartbeat_alert_uri) { URI.parse("http://fake-consul-cluster:8500/v1/event/fire/#{heartbeat_name}?") }
  let(:event_request) do
    { body: alert.to_json }
  end
  let(:heartbeat_request) do
    { body: simplified_heartbeat.to_json }
  end
  let(:heartbeat_name) { namespace + heartbeat.job + '_' + heartbeat.instance_id }
  let(:namespace) { 'ns_' }
  let(:new_port) { '9500' }
  let(:new_protocol) { 'https' }
  let(:new_params) { 'acl_token=testtoken' }
  let(:agent_base_url) { 'http://fake-consul-cluster:8500/v1/agent/check/' }
  let(:ttl_pass_uri) { URI.parse(agent_base_url + "pass/#{heartbeat_name}?") }
  let(:ttl_fail_uri) { URI.parse(agent_base_url + "fail/#{heartbeat_name}?") }
  let(:ttl_warn_uri) { URI.parse(agent_base_url + "warn/#{heartbeat_name}?") }
  let(:register_uri) { URI.parse(agent_base_url + 'register?') }
  let(:register_uri_with_port) { URI.parse("http://fake-consul-cluster:#{new_port}/v1/agent/check/register?") }
  let(:register_uri_with_protocol) { URI.parse("#{new_protocol}://fake-consul-cluster:8500/v1/agent/check/register?") }
  let(:register_uri_with_params) { URI.parse("http://fake-consul-cluster:8500/v1/agent/check/register?#{new_params}") }
  let(:register_request) do
    { body: { 'name' => "#{namespace}mysql_node_instance_id_abc", 'notes' => 'test', 'ttl' => '120s' }.to_json }
  end
  let(:register_request_with_namespace) do
    { body: { 'name' => "#{namespace}mysql_node_instance_id_abc", 'notes' => 'test', 'ttl' => '120s' }.to_json }
  end

  # we send a simplified version of a heartbeat to consul when sending as an event because consul has a 512byte limit for events
  let(:simplified_heartbeat) do
    {
      agent: 'deadbeef',
      name: 'mysql_node/instance_id_abc',
      id: 'instance_id_abc',
      state: 'running',
      data: {
        'cpu' => [22.3, 23.4, 33.22],
        'dsk' => {
          'eph' => [33, 74],
          'sys' => [74, 68],
        },
        'ld' => [0.2, 0.3, 0.6],
        'mem' => [32.2, 512_031],
        'swp' => [32.6, 231_312],
      },
    }
  end

  describe 'validating the options' do
    context 'when we specify host, endpoint and port' do
      let(:options) do
        { 'host' => 'fake-consul-cluster', 'protocol' => 'http', 'events_api' => '/v1/api', 'port' => 8500 }
      end
      it 'is valid' do
        subject.run
        expect(subject.validate_options).to eq(true)
      end
    end

    context 'when we omit the host' do
      let(:options) do
        { 'host' => nil }
      end
      it 'is not valid' do
        subject.run
        expect(subject.validate_options).to eq(false)
      end
    end

    context 'when we omit the enpoint and port' do
      let(:options) do
        { 'host' => 'fake-consul-cluster', 'protocol' => 'https', 'port' => 8500 }
      end

      it 'is valid' do
        subject.run
        expect(subject.validate_options).to eq(true)
      end
    end
  end

  describe 'forwarding alert messages to consul' do
    context 'without valid options' do
      let(:options) do
        { 'host' => nil }
      end
      it 'it should not forward events if options are invalid' do
        subject.run
        expect(subject).to_not receive(:send_http_put_request).with(alert_uri, event_request)
        subject.process(alert)
      end
    end

    context 'with valid options' do
      let(:options) do
        { 'host' => 'fake-consul-cluster', 'namespace' => namespace, 'events' => true, 'protocol' => 'http', 'port' => 8500 }
      end
      it 'should successully hand the alert off to http forwarder' do
        subject.run
        expect(subject).to receive(:send_http_put_request).with(alert_uri, event_request)
        subject.process(alert)
      end
    end
  end

  describe 'sending alerts to consul' do
    let(:options) do
      { 'host' => 'fake-consul-cluster', 'events' => true, 'namespace' => namespace, 'protocol' => 'http', 'port' => 8500 }
    end
    it 'should forward events when events are enabled' do
      subject.run
      expect(subject).to receive(:send_http_put_request).with(alert_uri, event_request)
      subject.process(alert)
    end
  end

  describe 'sending heartbeats as ttl requests to consul' do
    let(:options) do
      {
        'host' => 'fake-consul-cluster',
        'ttl' => '120s',
        'namespace' => namespace,
        'ttl_note' => 'test',
        'protocol' => 'http',
        'port' => 8500,
      }
    end

    it 'should send a put request to the register endpoint the first time an event is encountered' do
      subject.run
      expect(subject).to receive(:send_http_put_request).with(register_uri, register_request)
      subject.process(heartbeat)
    end

    it 'should properly send namespaced job name when namespace used' do
      options.merge!('namespace' => namespace)
      subject.run
      expect(subject).to receive(:send_http_put_request).with(register_uri, register_request_with_namespace)
      subject.process(heartbeat)
    end

    it 'should properly change the required port when a port is passed in options' do
      options.merge!('port' => new_port)
      subject.run
      expect(subject).to receive(:send_http_put_request).with(register_uri_with_port, register_request)
      subject.process(heartbeat)
    end

    it 'should properly change the protocol when a port is passed in options' do
      options.merge!('protocol' => new_protocol)
      subject.run
      expect(subject).to receive(:send_http_put_request).with(register_uri_with_protocol, register_request)
      subject.process(heartbeat)
    end

    it 'should properly provide params when params are passed in options' do
      options.merge!('params' => new_params)
      subject.run
      expect(subject).to receive(:send_http_put_request).with(register_uri_with_params, register_request)
      subject.process(heartbeat)
    end

    it 'should send a put request to the ttl endpoint the second time an event is encountered' do
      EM.run do
        subject.run
        subject.process(heartbeat)
        expect(subject).to receive(:send_http_put_request).with(ttl_pass_uri, heartbeat_request)
        subject.process(heartbeat)
        EM.stop
      end
    end

    it 'should send a fail ttl message when heartbeat is failing' do
      heartbeat.attributes['job_state'] = 'failing'
      EM.run do
        subject.run
        subject.process(heartbeat)
        expect(subject).to receive(:send_http_put_request).with(ttl_fail_uri, heartbeat_request)
        subject.process(heartbeat)
        EM.stop
      end
    end

    it 'should send a fail ttl message when heartbeat is unknown' do
      heartbeat.attributes['job_state'] = 'failing'

      EM.run do
        subject.run
        subject.process(heartbeat)
        expect(subject).to receive(:send_http_put_request).with(ttl_fail_uri, heartbeat_request)
        subject.process(heartbeat)
        EM.stop
      end
    end

    it 'should not send a registration request if an event is already registered' do
      subject.run
      EM.run do
        subject.process(heartbeat)
        EM.stop
      end

      expect(subject).to_not receive(:send_http_put_request).with(register_uri, register_request)
      subject.process(heartbeat)
    end

    describe 'when events are not enabled' do
      let(:options) do
        { 'host' => 'fake-consul-cluster', 'events' => false }
      end
      it 'should not forward events' do
        subject.run

        EM.run do
          subject.process(heartbeat)
          EM.stop
        end
        expect(subject).to_not receive(:send_http_put_request).with(alert_uri, event_request)
        subject.process(alert)
      end
    end

    describe 'when events are also enabled' do
      let(:options) do
        {
          'host' => 'fake-consul-cluster',
          'ttl' => '120s',
          'events' => true,
          'namespace' => namespace,
          'ttl_note' => 'test',
          'protocol' => 'http',
          'port' => 8500,
        }
      end

      it 'should not send ttl and event requests for same event' do
        subject.run

        EM.run do
          subject.process(heartbeat)
          EM.stop
        end
        expect(subject).to_not receive(:send_http_put_request).with(alert_uri, event_request)
        expect(subject).to receive(:send_http_put_request).with(ttl_pass_uri, heartbeat_request)
        subject.process(heartbeat)
      end

      describe 'When send heartbeats_as_alerts is enabled' do
        it 'should send both ttl and event request in the same loop ' do
          options.merge!('heartbeats_as_alerts' => true)
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

    describe 'when instance_id is missing from the heartbeat event' do
      it 'should not forward the event when heartbeats_as_alerts is set' do
        options.merge('heartbeats_as_alerts' => true, 'ttl' => nil)
        subject.run

        expect(subject).to_not receive(:notify_consul)
        subject.process(make_heartbeat(time: Time.now, instance_id: nil))
      end

      it 'should not forward the ttl for event when use_ttl is set' do
        options.merge('heartbeats_as_alerts' => nil, 'ttl' => '120s')
        subject.run

        expect(subject).to_not receive(:notify_consul)
        subject.process(make_heartbeat(time: Time.now, instance_id: nil))
      end
    end
  end
end
