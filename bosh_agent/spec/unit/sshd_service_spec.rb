require 'spec_helper'
require 'bosh_agent/sshd_service'

module Bosh::Agent
  describe SshdService do
    subject(:sshd_service) { SshdService.new }

    describe '#enable' do
      context 'when it is ok to stop' do
        # I know
        before { sshd_service.stub(ok_to_stop?: true) }
        it 'sets up a periodic timer to stop sshd in an EM thread' do
          EventMachine.should_receive(:add_periodic_timer).with(1).and_yield
          EventMachine.should_receive(:defer).and_yield

          sshd_service.should_receive(:stop_sshd).with() # I know :(

          sshd_service.enable(1, 2)
        end
      end

      context 'when it is not ok to stop' do
        # I aint proud of this stubbing
        before { sshd_service.stub(ok_to_stop?: false) }
        it 'the periodic timer wont start an EM thread to stop sshd' do
          EventMachine.should_receive(:add_periodic_timer).with(1).and_yield
          EventMachine.should_not_receive(:defer).and_yield

          sshd_service.enable(1, 2)
        end
      end
    end

    describe '#start_sshd' do
      before do
        EventMachine.stub(:add_periodic_timer)
        sshd_service.enable(0, 0)
      end

      let(:fake_lock) { double('lock') }
      before { Mutex.stub(new: fake_lock) }

      it 'shells out to start the ssh service' do
        fake_lock.stub(:synchronize).and_yield
        sshd_service.should_receive(:`).with('service ssh start') { `true` }
        sshd_service.start_sshd
      end

      context 'when the sshd start command fails' do
        before do
          sshd_service.stub(:`).with('service ssh start') { `false` }
          fake_lock.stub(:synchronize).and_yield
          sshd_service.stub(:sleep)
        end

        context 'when sshd status is started' do
          before { sshd_service.stub(:`).with('service ssh status') { `true`; 'running' } }

          it 'does not raise' do
            expect {
              sshd_service.start_sshd
            }.not_to raise_error
          end
        end

        context 'when sshd status is not started' do
          before { sshd_service.stub(:`).with('service ssh status') { `true`; 'stopped' } }

          it 'raises' do
            expect {
              sshd_service.start_sshd
            }.to raise_error('Failed to start sshd')
          end
        end

        context 'when sshd status was not started but it becomes started on a second attempt' do
          it 'does not raise' do
            sshd_service.should_receive(:`).ordered.with('service ssh status') { `true`; 'stopped' }
            sshd_service.should_receive(:`).ordered.with('service ssh status') { `true`; 'running' }
            expect {
              sshd_service.start_sshd
            }.not_to raise_error
          end
        end
      end
    end

    describe '#stop_sshd' do
      let(:fake_lock) { double('lock') }
      before { Mutex.stub(new: fake_lock) }

      before { sshd_service.stub(ok_to_stop?: true) }

      before do
        EventMachine.stub(:add_periodic_timer)
        sshd_service.enable(0, 0)
      end

      it 'shells out to stop the ssh service' do
        fake_lock.stub(:synchronize).and_yield
        sshd_service.should_receive(:`).with('service ssh stop')
        sshd_service.stop_sshd
      end

      context 'when the sshd start command fails' do
        before do
          sshd_service.stub(:`).with('service ssh stop') { `false` }
          fake_lock.stub(:synchronize).and_yield
          sshd_service.stub(:sleep)
        end

        context 'when sshd status is stopped' do
          before { sshd_service.stub(:`).with('service ssh status') { `true`; 'stop' } }

          it 'does not raise' do
            expect {
              sshd_service.stop_sshd
            }.not_to raise_error
          end
        end

        context 'when sshd status is not stopped' do
          before { sshd_service.stub(:`).with('service ssh status') { `true`; 'running' } }

          it 'raises' do
            expect {
              sshd_service.stop_sshd
            }.to raise_error('Failed to stop sshd')
          end
        end

        context 'when sshd status was not stopped but it becomes stopped on a second attempt' do
          it 'does not raise' do
            sshd_service.should_receive(:`).ordered.with('service ssh status') { `true`; 'running' }
            sshd_service.should_receive(:`).ordered.with('service ssh status') { `true`; 'stop' }
            expect {
              sshd_service.stop_sshd
            }.not_to raise_error
          end
        end
      end
    end
  end
end
