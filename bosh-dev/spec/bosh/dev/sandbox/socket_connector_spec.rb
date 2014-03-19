require 'spec_helper'
require 'logger'
require 'bosh/dev/sandbox/socket_connector'

module Bosh::Dev::Sandbox
  describe SocketConnector do
    let(:socket_connector) { SocketConnector.new('fake-name', 'fake-host', 'fake-port', logger) }
    let(:logger) { Logger.new('/dev/null') }

    describe '#try_to_connect' do
      context 'when connecting fails after some time' do
        before { Timeout.stub(:timeout).and_raise(error) }
        let(:error) { Timeout::Error.new }

        it 'sleeps after each failed attempt then raises' do
          Timeout.should_receive(:timeout).ordered
          socket_connector.should_receive(:sleep).with(0.2).ordered
          Timeout.should_receive(:timeout).ordered

          expect {
            socket_connector.try_to_connect(2)
          }.to raise_error(error)
        end

        it 'defaults to 40 attempts before raising' do
          Timeout.should_receive(:timeout).exactly(40).times
          socket_connector.should_receive(:sleep).exactly(39).times

          expect {
            socket_connector.try_to_connect
          }.to raise_error(error)
        end

        it 'logs name, error and other misc information if error raised' do
          socket_connector.stub(:sleep)

          expect(logger).to receive(:error).at_least(1).with(
            /Failed to connect to fake-name: .*Timeout::Error.*fake-host.*fake-port/)

          expect {
            socket_connector.try_to_connect
          }.to raise_error(error)
        end
      end
    end
  end
end
