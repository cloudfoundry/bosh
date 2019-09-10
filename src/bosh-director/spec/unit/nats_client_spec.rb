require 'spec_helper'

describe Bosh::Director::NatsClient do
  let(:use_nats_pure) { true }

  subject(:nats_client) do
    Bosh::Director::NatsClient.new(use_nats_pure)
  end

  describe '#initialize' do
    context 'use nats pure (NATS::IO)' do
      let(:use_nats_pure) { true }

      it 'initializes the nats pure client' do
        allow(Bosh::Director::NatsPureClientAdapter).to receive(:new)

        Bosh::Director::NatsClient.new(use_nats_pure)

        expect(Bosh::Director::NatsPureClientAdapter).to have_received(:new)
      end
    end

    context 'use nats (NATS)' do
      let(:use_nats_pure) { false }

      it 'does not initialize the nats pure client' do
        allow(Bosh::Director::NatsClientAdapter).to receive(:new)

        Bosh::Director::NatsClient.new(use_nats_pure)

        expect(Bosh::Director::NatsClientAdapter).to have_received(:new)
      end
    end
  end

  describe '#connect' do
    let(:options) do
      {
        fake_key: 'fake_value',
      }
    end

    context 'use nats pure (NATS::IO)' do
      let(:use_nats_pure) { true }
      let(:nats_client_adapter) { instance_double('Bosh::Director::NatsPureClientAdapter') }

      it 'calls connect on nats pure client adapter' do
        allow(Bosh::Director::NatsPureClientAdapter).to receive(:new).and_return(nats_client_adapter)
        allow(nats_client_adapter).to receive(:options).and_return(options)
        allow(nats_client_adapter).to receive(:connect)

        nats_client.connect('uri', 'client-private-key-path', 'client-cert-path', 'server-ca-path')

        expect(nats_client_adapter).to have_received(:connect).with(options)
      end
    end

    context 'use nats (NATS)' do
      let(:use_nats_pure) { false }
      let(:nats_client_adapter) { instance_double('Bosh::Director::NatsClientAdapter') }

      it 'calls connect on nats client adapter' do
        allow(Bosh::Director::NatsClientAdapter).to receive(:new).and_return(nats_client_adapter)
        allow(nats_client_adapter).to receive(:options).and_return(options)
        allow(nats_client_adapter).to receive(:connect)
        nats_client.connect('uri', 'client-private-key-path', 'client-cert-path', 'server-ca-path')

        expect(nats_client_adapter).to have_received(:connect).with(options)
      end
    end
  end

  describe '#on_error' do
    context 'use nats pure' do
      let(:use_nats_pure) { true }
      let(:nats_pure_client) { instance_double('NATS::IO::Client') }
      let(:nats_client_adapter) { instance_double('Bosh::Director::NatsPureClientAdapter') }

      it 'calls on_error of the nats pure client' do
        allow(Bosh::Director::NatsPureClientAdapter).to receive(:new).and_return(nats_client_adapter)
        allow(nats_client_adapter).to receive(:on_error)

        nats_client.on_error {}

        expect(nats_client_adapter).to have_received(:on_error)
      end
    end

    context 'use nats rb client' do
      let(:use_nats_pure) { false }
      let(:nats_client_adapter) { instance_double('Bosh::Director::NatsClientAdapter') }

      it 'calls on_error of the nats rb client' do
        allow(Bosh::Director::NatsClientAdapter).to receive(:new).and_return(nats_client_adapter)
        allow(nats_client_adapter).to receive(:on_error)

        nats_client.on_error {}

        expect(nats_client_adapter).to have_received(:on_error)
      end
    end
  end

  describe '#schedule' do
    context 'use nats pure' do
      let(:use_nats_pure) { true }
      let(:nats_client_adapter) { instance_double('Bosh::Director::NatsPureClientAdapter') }

      it 'calls on_error of the nats pure client' do
        allow(Bosh::Director::NatsPureClientAdapter).to receive(:new).and_return(nats_client_adapter)
        allow(nats_client_adapter).to receive(:schedule)

        nats_client.schedule {}

        expect(nats_client_adapter).to have_received(:schedule)
      end
    end

    context 'use nats rb client' do
      let(:use_nats_pure) { false }
      let(:nats_client_adapter) { instance_double('Bosh::Director::NatsClientAdapter') }

      it 'calls on_error of the nats rb client' do
        allow(Bosh::Director::NatsClientAdapter).to receive(:new).and_return(nats_client_adapter)
        allow(nats_client_adapter).to receive(:schedule)

        nats_client.schedule {}

        expect(nats_client_adapter).to have_received(:schedule)
      end
    end
  end
end

describe Bosh::Director::NatsPureClientAdapter do
  subject(:nats_pure_client_adapter) do
    Bosh::Director::NatsPureClientAdapter.new
  end

  let(:nats_pure_client) { instance_double('NATS::IO::Client') }

  let(:options) do
    {
      fake_key: 'fake_value',
    }
  end

  let(:nats_pure_client) { instance_double('NATS::IO::Client') }

  before do
    allow(NATS::IO::Client).to receive(:new).and_return(nats_pure_client)
    allow(nats_pure_client).to receive(:connect)
  end

  describe '#connect' do
    it 'configures the pure nats client' do
      allow(nats_pure_client).to receive(:on_error)

      nats_pure_client_adapter.connect(options)

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
      nats_pure_client_adapter.connect(options)

      expect(nats_pure_client).to have_received(:on_error)
      expect(block_called).to eq(true)
    end
  end

  describe '#subscribe' do
    it 'calls the clients subscribe' do
      allow(nats_pure_client).to receive(:subscribe).and_yield
      block_called = false

      nats_pure_client_adapter.connect(options)
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

      nats_pure_client_adapter.connect(options)
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

      nats_pure_client_adapter.connect(options)
      nats_pure_client_adapter.flush do
        block_called = true
      end

      expect(nats_pure_client).to have_received(:flush)
      expect(block_called).to eq(true)
    end
  end
end

describe Bosh::Director::NatsClientAdapter do
  subject(:nats_client_adapter) do
    Bosh::Director::NatsClientAdapter.new
  end

  let(:nats_client) { instance_double('NATS') }

  let(:options) do
    {
      fake_key: 'fake_value',
    }
  end

  before do
    allow(NATS).to receive(:connect).and_return(nats_client)
  end

  describe '#connect' do
    it 'configures the pure nats client' do
      nats_client_adapter.connect(options)

      expect(NATS).to have_received(:connect).with(options)
    end
  end

  describe '#on_error' do
    it 'changes the default error handler' do
      callback_passed = false
      allow(NATS).to receive(:on_error).and_yield

      nats_client_adapter.on_error do
        callback_passed = true
      end

      expect(NATS).to have_received(:on_error)
      expect(callback_passed).to eq(true)
    end
  end

  describe '#subscribe' do
    it 'calls the clients subscribe' do
      allow(nats_client).to receive(:subscribe).and_yield
      block_called = false

      nats_client_adapter.connect(options)
      nats_client_adapter.subscribe('fake-subject') do
        block_called = true
      end

      expect(nats_client).to have_received(:subscribe).with('fake-subject')
      expect(block_called).to eq(true)
    end
  end

  describe '#publish' do
    it 'calls the clients publish' do
      allow(nats_client).to receive(:publish).and_yield
      block_called = false

      nats_client_adapter.connect(options)
      nats_client_adapter.publish('fake-subject', '') do
        block_called = true
      end

      expect(nats_client).to have_received(:publish).with('fake-subject', '')
      expect(block_called).to eq(true)
    end
  end

  describe '#flush' do
    it 'calls the clients flush' do
      allow(nats_client).to receive(:flush).and_yield
      block_called = false

      nats_client_adapter.connect(options)
      nats_client_adapter.flush do
        block_called = true
      end

      expect(nats_client).to have_received(:flush)
      expect(block_called).to eq(true)
    end
  end
end
