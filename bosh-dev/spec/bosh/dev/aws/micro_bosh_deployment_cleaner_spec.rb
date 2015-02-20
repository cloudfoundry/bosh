require 'spec_helper'
require 'bosh/dev/aws/micro_bosh_deployment_cleaner'
require 'bosh/dev/aws/micro_bosh_deployment_manifest'

module Bosh::Dev::Aws
  describe MicroBoshDeploymentCleaner do
    describe '#clean' do
      subject(:micro_bosh_deployment_cleaner) { described_class.new(manifest) }

      let(:manifest) do
        instance_double(
          'Bosh::Dev::Aws::MicroBoshDeploymentManifest',
          access_key_id: 'fake-access-key-id',
          secret_access_key: 'fake-secret-access-key',
          director_name: 'fake-director-name',
        )
      end

      before { allow(AWS::EC2).to receive_messages(new: ec2) }
      let(:ec2) { instance_double('AWS::EC2', instances: []) }

      it 'connects to ec2 with credentials from manifest' do
        expect(AWS::EC2).to receive(:new).with(
          access_key_id: 'fake-access-key-id',
          secret_access_key: 'fake-secret-access-key',
        ).and_return(ec2)

        micro_bosh_deployment_cleaner.clean
      end

      context 'when matching instances are found' do
        it 'terminates vms that have specific microbosh tag name and are not already terminated' do
          instance_with_non_matching =
            instance_double('AWS::EC2::Instance', tags: { 'director' => 'non-matching-tag-value' })
          allow(instance_with_non_matching).to receive(:status).and_return(:running, :terminated)
          expect(instance_with_non_matching).not_to receive(:terminate)

          instance_with_matching =
            instance_double('AWS::EC2::Instance', tags: { 'director' => 'fake-director-name' })
          allow(instance_with_matching).to receive(:status).and_return(:running, :terminated)
          expect(instance_with_matching).to receive(:terminate)

          microbosh_instance =
            instance_double('AWS::EC2::Instance', tags: { 'Name' => 'fake-director-name' })
          allow(microbosh_instance).to receive(:status).and_return(:running, :terminated)
          expect(microbosh_instance).to receive(:terminate)

          terminated_instance_with_matching =
            instance_double('AWS::EC2::Instance', tags: { 'director' => 'fake-director-name' }, status: :terminated)
          expect(terminated_instance_with_matching).not_to receive(:terminate)

          allow(ec2).to receive_messages(instances: [
            instance_with_non_matching,
            instance_with_matching,
            microbosh_instance,
            terminated_instance_with_matching,
          ])

          micro_bosh_deployment_cleaner.clean
        end

        it 'waits for all the matching instances to be terminated' +
           '(instances lose their IP association when instance becomes terminated, not shutting down)' do
          matching_tags = { 'director' => 'fake-director-name' }
          instance1 = instance_double('AWS::EC2::Instance', tags: matching_tags, terminate: nil)
          instance2 = instance_double('AWS::EC2::Instance', tags: matching_tags, terminate: nil)
          allow(ec2).to receive_messages(instances: [instance1, instance2])

          retryable = instance_double('Bosh::Retryable')
          allow(Bosh::Retryable).to receive_messages(new: retryable)

          expect(retryable).to receive(:retryer) do |&blk|
            allow(instance1).to receive_messages(status: :terminated)
            allow(instance2).to receive_messages(status: :shutting_down)
            expect(blk.call).to be(false)

            allow(instance1).to receive_messages(status: :terminated)
            allow(instance2).to receive_messages(status: :terminated)
            expect(blk.call).to be(true)
          end

          allow(instance1).to receive_messages(status: :running)
          allow(instance2).to receive_messages(status: :running)
          micro_bosh_deployment_cleaner.clean
        end
      end

      context 'when matching instances are not found' do
        it 'finishes without waiting for anything' do
          allow(ec2).to receive_messages(instances: [])
          micro_bosh_deployment_cleaner.clean
        end
      end
    end
  end
end
