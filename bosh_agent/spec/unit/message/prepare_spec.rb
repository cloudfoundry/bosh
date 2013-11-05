require 'spec_helper'
require 'bosh_agent/message/prepare'

module Bosh::Agent::Message
  describe Prepare do
    subject(:message) { described_class.new(apply_spec) }
    let(:apply_spec) { {} }

    before { Bosh::Agent::Config.stub(platform: platform) }
    let(:platform) { instance_double('Bosh::Agent::Platform::Linux::Adapter') }

    describe '.process' do
      it 'runs apply message' do
        message = instance_double('Bosh::Agent::Message::Prepare')
        described_class
          .should_receive(:new)
          .with(apply_spec)
          .and_return(message)
        message.should_receive(:run)
        described_class.process([apply_spec])
      end
    end

    describe '#initialize' do
      context 'when non hash is passed as prepare data to initializer' do
        it 'raises helpful error' do
          expect {
            described_class.new(double('non-hash'))
          }.to raise_error(ArgumentError, /invalid spec, Hash expected/)
        end
      end
    end

    describe '#run' do
      before do
        apply_spec.merge!(
          'job' => {
            'name' => 'fake-job1-name',
            'template' => 'fake-job1-template',
            'blobstore_id' => 'fake-job1-blob-id',
            'version' => 'fake-job1-version',
            'sha1' => 'fake-job1-sha1'
          },
          'packages' => {
            'fake-package1' => {
              'name' => 'fake-package1-name',
              'version' => 'fake-package1-version',
              'blobstore_id' => 'fake-package1-blob-id',
              'sha1' => 'fake-package1-sha1'
            }
          }
        )
      end

      it 'prepares jobs and packages for install' do
        job1 = instance_double('Bosh::Agent::ApplyPlan::Job')
        Bosh::Agent::ApplyPlan::Job
          .should_receive(:new)
          .with('fake-job1-name', anything, anything, anything)
          .and_return(job1)
        job1.should_receive(:prepare_for_install)

        package1 = instance_double('Bosh::Agent::ApplyPlan::Package')
        Bosh::Agent::ApplyPlan::Package
          .should_receive(:new)
          .with(hash_including('name' => 'fake-package1-name'))
          .and_return(package1)
        package1.should_receive(:prepare_for_install)

        expect(message.run).to eq({})
      end

      context 'when job preparation for install fails' do
        before do
          job1 = instance_double('Bosh::Agent::ApplyPlan::Job')
          job1.stub(:prepare_for_install).and_raise(Exception.new('error'))
          Bosh::Agent::ApplyPlan::Job.stub(new: job1)
        end

        it 'raises MessageHandlerError instead of propagating other error for message processor to catch it' do
          expect { message.run }.to raise_error(Bosh::Agent::MessageHandlerError, /error/)
        end
      end

      context 'when package preparation for install fails' do
        before do
          job1 = instance_double('Bosh::Agent::ApplyPlan::Job', prepare_for_install: nil)
          Bosh::Agent::ApplyPlan::Job.stub(new: job1)
        end

        before do
          package1 = instance_double('Bosh::Agent::ApplyPlan::Package')
          package1.stub(:prepare_for_install).and_raise(Exception.new('error'))
          Bosh::Agent::ApplyPlan::Package.stub(new: package1)
        end

        it 'raises MessageHandlerError instead of propagating other error for message processor to catch it' do
          expect { message.run }.to raise_error(Bosh::Agent::MessageHandlerError, /error/)
        end
      end
    end
  end
end
