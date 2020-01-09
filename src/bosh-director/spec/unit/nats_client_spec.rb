require 'spec_helper'

describe Bosh::Director::NatsClient do
  subject(:nats_pure_client_adapter) do
    Bosh::Director::NatsClient.new
  end

  let(:nats_pure_client) { instance_double('NATS::IO::Client') }

  before do
    allow(NATS::IO::Client).to receive(:new).and_return(nats_pure_client)
    allow(nats_pure_client).to receive(:connect)
  end

  describe '#connect' do
    let(:tls_context) {  {  fake_tls: "so-fake"  }  }
    it 'configures the pure nats client' do
      allow(nats_pure_client).to receive(:on_error)
      allow(nats_pure_client_adapter).to recieve(:create_tls_context).and_return(:tls_context)
      options = {
        servers: Array.new(Bosh::Director::MAX_RECONNECT_ATTEMPTS, 'uri'),
        dont_randomize_servers: true,
        max_reconnect_attempts: Bosh::Director::MAX_RECONNECT_ATTEMPTS,
        reconnect_time_wait: 0.5,
        reconnect: true,
        tls: {
          context: tls_context,
        },
      }
      nats_pure_client_adapter.connect('uri', 'client-private-key-path', 'client-cert-path', 'server-ca-path')

      expect(NATS::IO::Client).to have_received(:new)
      expect(nats_pure_client).to have_received(:connect).with(options)
      expect(nats_pure_client).to_not have_received(:on_error)
    end
  end

  describe '#on_error' do
    it 'changes the default error handler' do
      allow(nats_pure_client).to receive(:on_error).and_yield
      block_called = false

      nats_pure_client_adapter.on_error do
        block_called = true
      end
      nats_pure_client_adapter.connect('uri', 'client-private-key-path', 'client-cert-path', 'server-ca-path')

      expect(nats_pure_client).to have_received(:on_error)
      expect(block_called).to eq(true)
    end
  end

  describe '#subscribe' do
    it 'calls the clients subscribe' do
      allow(nats_pure_client).to receive(:subscribe).and_yield
      block_called = false

      nats_pure_client_adapter.connect('uri', 'client-private-key-path', 'client-cert-path', 'server-ca-path')
      nats_pure_client_adapter.subscribe('fake-subject') do
        block_called = true
      end

      expect(nats_pure_client).to have_received(:subscribe).with('fake-subject')
      expect(block_called).to eq(true)
    end
  end

  describe '#publish' do
    it 'calls the clients publish' do
      allow(nats_pure_client).to receive(:publish).and_yield
      block_called = false

      nats_pure_client_adapter.connect('uri', 'client-private-key-path', 'client-cert-path', 'server-ca-path')
      nats_pure_client_adapter.publish('fake-subject', '') do
        block_called = true
      end

      expect(nats_pure_client).to have_received(:publish).with('fake-subject', '')
      expect(block_called).to eq(true)
    end
  end

  describe '#flush' do
    it 'calls the clients flush' do
      allow(nats_pure_client).to receive(:flush)
      block_called = false

      nats_pure_client_adapter.connect('uri', 'client-private-key-path', 'client-cert-path', 'server-ca-path')
      nats_pure_client_adapter.flush do
        block_called = true
      end

      expect(nats_pure_client).to have_received(:flush)
      expect(block_called).to eq(true)
    end
  end
end
