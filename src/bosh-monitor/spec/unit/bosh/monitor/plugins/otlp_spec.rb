require 'spec_helper'

describe Bosh::Monitor::Plugins::Otlp do
  subject(:plugin) { described_class.new(options) }

  let(:options) do
    { 'endpoint' => 'http://127.0.0.1:4318' }
  end

  describe '#validate_options' do
    it 'requires endpoint' do
      expect(described_class.new({}).validate_options).to be_falsey
      expect(described_class.new('endpoint' => 'http://127.0.0.1:4318').validate_options).to be_truthy
    end
  end

  describe '#run' do
    context "when event loop isn't running" do
      it 'returns false' do
        expect(plugin.run).to be(false)
      end
    end

    context 'when event loop is running' do
      include_context Async::RSpec::Reactor

      it 'logs that the agent is running' do
        expect(Bosh::Monitor.logger).to receive(:info).with('OTLP delivery agent is running...')
        plugin.run
      end
    end
  end

  describe '#process' do
    include_context Async::RSpec::Reactor

    before { plugin.run }

    context 'when event is an Alert' do
      it 'does not send a request' do
        event = make_alert(timestamp: Time.now.to_i)
        expect(plugin).not_to receive(:send_http_post_request)
        plugin.process(event)
      end
    end

    context 'when heartbeat is missing instance_id' do
      it 'does not send a request' do
        event = make_heartbeat(timestamp: Time.now.to_i, instance_id: nil)
        expect(plugin).not_to receive(:send_http_post_request)
        plugin.process(event)
      end
    end

    context 'when event is a Heartbeat' do
      let(:timestamp) { Time.now.to_i }
      let(:event) { make_heartbeat(timestamp: timestamp) }

      it 'posts to the OTLP metrics endpoint' do
        expect(plugin).to receive(:send_http_post_request) do |args|
          expect(args[:uri]).to eq('http://127.0.0.1:4318/v1/metrics')
          expect(args[:request][:head]['Content-Type']).to eq('application/json')

          body = JSON.parse(args[:request][:body])
          resource_metrics = body['resourceMetrics'].first

          attributes = resource_metrics['resource']['attributes']
          expect(attributes).to include('key' => 'bosh.deployment', 'value' => { 'stringValue' => event.deployment })
          expect(attributes).to include('key' => 'bosh.job',        'value' => { 'stringValue' => event.job })
          expect(attributes).to include('key' => 'bosh.id',         'value' => { 'stringValue' => event.instance_id })
          expect(attributes).to include('key' => 'bosh.agent_id',   'value' => { 'stringValue' => event.agent_id })

          metrics = resource_metrics['scopeMetrics'].first['metrics']
          expect(metrics.length).to eq(event.metrics.length)

          metric_names = metrics.map { |m| m['name'] }
          event.metrics.each do |m|
            expect(metric_names).to include(m.name)
          end

          data_point = metrics.first['gauge']['dataPoints'].first
          expect(data_point['timeUnixNano']).to eq((timestamp * 1_000_000_000).to_s)
        end

        plugin.process(event)
      end

      context 'when ca_cert is configured' do
        let(:options) { { 'endpoint' => 'https://otelcol.internal:4318', 'ca_cert' => '/var/vcap/jobs/health_monitor/config/otelcol_ca.pem' } }

        it 'passes ca_cert to the HTTP helper' do
          expect(plugin).to receive(:send_http_post_request) do |args|
            expect(args[:ca_cert_path]).to eq('/var/vcap/jobs/health_monitor/config/otelcol_ca.pem')
          end
          plugin.process(event)
        end
      end
    end
  end
end
