require 'spec_helper'

require 'bosh/deployer/remote_tunnel'
require 'net/ssh'

module Bosh::Deployer
  describe RemoteTunnel do
    subject do
      RemoteTunnel.new(
        ssh_server,
        wait,
        logger,
      )
    end

    let(:ssh_server) { instance_double('Bosh::Deployer::SshServer') }
    let(:wait) { 60 }
    let(:logger) { instance_double('Logger', debug: nil, info: nil) }

    describe '#create' do
      let(:session) { instance_double('Net::SSH::Connection::Session') }
      let(:forward_service) { instance_double('Net::SSH::Service::Forward') }

      before do
        allow(Kernel).to receive(:sleep)
        allow(Kernel).to receive(:at_exit)
        allow(Thread).to receive(:new)

        allow(ssh_server).to receive(:readable?).and_return(true)
        allow(ssh_server).to receive(:start_session).and_return(session)
        allow(session).to receive(:forward).and_return(forward_service)
        allow(forward_service).to receive(:remote)
      end

      context 'when a session already exists for a given port' do
        it 'does nothing' do
          subject.create('fake-ip', 8080)
          subject.create('fake-ip', 8080)
          expect(ssh_server).to have_received(:readable?).once
          expect(ssh_server).to have_received(:start_session).once
        end
      end

      it 'checks to see that the ssh socket is readable' do
        subject.create('fake-ip', 8080)

        expect(ssh_server).to have_received(:readable?).with('fake-ip')
      end

      it 'retries indefinitely until the ssh socket is readable' do
        failures = 100.times.map { false }
        allow(ssh_server).to receive(:readable?).and_return(*failures, true)

        subject.create('fake-ip', 8080)

        expect(ssh_server).to have_received(:readable?).exactly(failures.count + 1).times
      end

      it 'sleeps for ssh wait period for host keys to be generated' do
        subject.create('fake-ip', 8080)
        expect(Kernel).to have_received(:sleep).with(wait)
      end

      it 'establishes a ssh session' do
        subject.create('fake-ip', 8080)
        expect(ssh_server).to have_received(:start_session).with('fake-ip')
      end

      context 'when ssh start session fails' do
        it 'retries establishing the ssh session indefinitely' do
          allow(ssh_server).to receive(:start_session).and_return(nil, nil, nil, session)

          subject.create('fake-ip', 8080)

          expect(ssh_server).to have_received(:start_session).exactly(4).times
        end
      end

      it 'forwards the local port to the remote port' do
        subject.create('fake-ip', 8080)

        expect(forward_service).to have_received(:remote).with(8080, '127.0.0.1', 8080)
      end

      it 'spawns a thread to keep the session alive' do
        subject.create('fake-ip', 8080)

        expect(Thread).to have_received(:new)
      end

      it 'closes sessions at process exist' do
        subject.create('fake-ip', 8080)

        expect(Kernel).to have_received(:at_exit)
      end
    end
  end
end
