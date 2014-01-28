require 'spec_helper'

require 'bosh/deployer/ssh_server'
require 'logger'

module Bosh::Deployer
  describe SshServer do
    subject { SshServer.new('fake-user', 'fake-key', 'fake-port', logger) }
    let(:logger) { instance_double('Logger', debug: nil, info: nil) }

    before do
      allow(Kernel).to receive(:sleep)
    end

    describe '#readable?' do
      let(:socket) { instance_double('TCPSocket', close: nil) }

      before do
        allow(TCPSocket).to receive(:new).and_return(socket)
        allow(IO).to receive(:select).and_return([socket])
      end

      context 'socket is readable within 5 seconds' do
        it 'returns true' do
          expect(subject.readable?('fake-ip')).to be_truthy
          expect(IO).to have_received(:select).with([socket], nil, nil, 5)
        end

        it 'closes the socket' do
          subject.readable?('fake-ip')
          expect(socket).to have_received(:close)
        end
      end

      context 'socket is not readable within 5 seconds' do
        before do
          allow(IO).to receive(:select).and_return(nil)
        end

        it 'returns false' do
          expect(subject.readable?('fake-ip')).to be_falsey
        end
      end

      context 'when waiting for read fails with SocketError' do
        before do
          allow(IO).to receive(:select).and_raise(SocketError, 'fake-socket-error')
        end

        it 'sleeps for 1 second' do
          subject.readable?('fake-ip')
          expect(Kernel).to have_received(:sleep).with(1)
        end

        it 'returns false' do
          expect(subject.readable?('fake-ip')).to be_falsey
        end

        it 'closes the socket' do
          subject.readable?('fake-ip')
          expect(socket).to have_received(:close)
        end
      end
    end

    describe '#start_session' do
      let(:session) { instance_double('Net::SSH::Connection::Session') }

      before do
        allow(Net::SSH).to receive(:start).and_return(session)
      end

      it 'returns an ssh session to the server' do
        expect(subject.start_session('fake-ip')).to eq(session)
        expect(Net::SSH).to have_received(:start).with(
                              'fake-ip',
                              'fake-user',
                              keys: ['fake-key'],
                              paranoid: false,
                              port: 'fake-port',
                            )
      end

      context 'when it raises and ssh exception' do
        before do
          allow(Net::SSH).to receive(:start)
                             .and_raise(Net::SSH::AuthenticationFailed, 'fake-auth-error')
        end

        it 'returns nil for the session' do
          expect(subject.start_session('fake-ip')).to be_nil
        end

        it 'sleeps for 1 second' do
          subject.start_session('fake-ip')
          expect(Kernel).to have_received(:sleep).with(1)
        end
      end
    end
  end
end
