require 'spec_helper'
require 'logger'
require 'bosh/dev/sandbox/socket_connector'

module Bosh::Dev::Sandbox
  describe SocketConnector do
    let(:socket_connector) { SocketConnector.new('fake host', 'fake port', logger) }
    let(:logger) { Logger.new('/dev/null') }

    before { Timeout.stub(:timeout).and_raise(Timeout::Error, 'Timeout error') }

    describe '#try_to_connect' do
      it 'sleeps after each failed attempt then raises' do
        Timeout.should_receive(:timeout).ordered
        socket_connector.should_receive(:sleep).with(0.2).ordered
        Timeout.should_receive(:timeout).ordered
        expect { socket_connector.try_to_connect(2) }.to raise_error(Timeout::Error, 'Timeout error')
      end

      it 'defaults to 40 attempts before raising' do
        Timeout.should_receive(:timeout).exactly(40).times
        socket_connector.should_receive(:sleep).exactly(39).times
        expect { socket_connector.try_to_connect }.to raise_error(Timeout::Error, 'Timeout error')
      end
    end
  end
end
