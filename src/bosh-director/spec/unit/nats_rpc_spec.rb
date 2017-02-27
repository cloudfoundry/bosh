require 'spec_helper'

describe Bosh::Director::NatsRpc do
  let(:nats) { instance_double('NATS') }
  let(:nats_url) { 'fake-nats-url' }
  let(:nats_options) { {uri: nats_url, autostart: false, ssl: true} }
  subject(:nats_rpc) { Bosh::Director::NatsRpc.new(nats_url) }

  before do
    expect(NATS).to receive(:connect).with(nats_options).and_return(nats)
    allow(Bosh::Director::Config).to receive(:process_uuid).and_return(123)
    allow(EM).to receive(:schedule).and_yield
    allow(nats_rpc).to receive(:generate_request_id).and_return('req1')
  end

  describe 'send_request' do
    it 'should publish a message to the client' do
      expect(nats).to receive(:subscribe).with('director.123.>')
      expect(nats).to receive(:publish) do |subject, message|
        expect(subject).to eql('test_client')
        payload = JSON.parse(message)
        expect(payload).to eql({
          'method' => 'a',
          'arguments' => [5],
          'reply_to' => 'director.123.req1'
        })
      end

      request_id = nats_rpc.send_request('test_client',  {'method' => 'a', 'arguments' => [5]})
      expect(request_id).to eql('req1')
    end

    it 'should execute the callback when the message is received' do
      subscribe_callback = nil
      expect(nats).to receive(:subscribe).with('director.123.>') do |&block|
        subscribe_callback = block
      end
      expect(nats).to receive(:publish) do
        subscribe_callback.call('', nil, 'director.123.req1')
      end

      callback_called = false
      nats_rpc.send_request('test_client', {'method' => 'a', 'arguments' => [5]}) do
        callback_called = true
      end
      expect(callback_called).to be(true)
    end

    it 'should execute the callback once even when two messages were received' do
      subscribe_callback = nil
      expect(nats).to receive(:subscribe).with('director.123.>') do |&block|
        subscribe_callback = block
      end
      expect(nats).to receive(:publish) do
        subscribe_callback.call('', nil, 'director.123.req1')
        subscribe_callback.call('', nil, 'director.123.req1')
      end

      called_times = 0
      nats_rpc.send_request('test_client', {'method' => 'a', 'arguments' => [5]}) do
        called_times += 1
      end
      expect(called_times).to eql(1)
    end

  end

  describe 'cancel_request' do
    it 'should not fire after cancel was called' do
      subscribe_callback = nil
      expect(nats).to receive(:subscribe).with('director.123.>') do |&block|
        subscribe_callback = block
      end
      expect(nats).to receive(:publish)

      called = false
      request_id = nats_rpc.send_request('test_client', {'method' => 'a', 'arguments' => [5]}) do
        called = true
      end
      expect(request_id).to eql('req1')

      nats_rpc.cancel_request('req1')
      subscribe_callback.call('', nil, 'director.123.req1')
      expect(called).to be(false)
    end
  end
end
