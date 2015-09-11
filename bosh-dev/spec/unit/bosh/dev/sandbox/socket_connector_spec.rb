require 'spec_helper'
require 'bosh/dev/sandbox/socket_connector'

module Bosh::Dev::Sandbox
  describe SocketConnector do
    let(:socket_connector) { SocketConnector.new('fake-name', 'fake-host', 'fake-port', 'fake-log-location', logger) }

    describe '#try_to_connect' do
      context 'when connecting fails after some time' do
        before { allow(Timeout).to receive(:timeout).and_raise(error) }
        let(:error) { Timeout::Error.new }

        it 'sleeps after each failed attempt then raises' do
          expect(Timeout).to receive(:timeout).ordered
          expect(socket_connector).to receive(:sleep).with(0.2).ordered
          expect(Timeout).to receive(:timeout).ordered

          expect {
            socket_connector.try_to_connect(2)
          }.to raise_error(error)
        end

        it 'defaults to 40 attempts before raising' do
          expect(Timeout).to receive(:timeout).exactly(80).times
          expect(socket_connector).to receive(:sleep).exactly(79).times

          expect {
            socket_connector.try_to_connect
          }.to raise_error(error)
        end

        it 'logs name, error and other misc information if error raised' do
          allow(socket_connector).to receive(:sleep)

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
