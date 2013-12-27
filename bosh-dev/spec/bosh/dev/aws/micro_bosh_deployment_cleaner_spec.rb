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

      before { AWS::EC2.stub(new: ec2) }
      let(:ec2) { instance_double('AWS::EC2', instances: []) }

      it 'connects to ec2 with credentials from manifest' do
        AWS::EC2.should_receive(:new).with(
          access_key_id: 'fake-access-key-id',
          secret_access_key: 'fake-secret-access-key',
        ).and_return(ec2)

        micro_bosh_deployment_cleaner.clean
      end

      before { Logger.stub(new: logger) }
      let(:logger) { instance_double('Logger', info: nil) }

      context 'when matching instances are found' do
        it 'terminates vms that have specific microbosh tag name and are not already terminated' do
          instance_with_non_matching =
            instance_double('AWS::EC2::Instance', tags: { 'director' => 'non-matching-tag-value' })
          instance_with_non_matching.stub(:status).and_return(:running, :terminated)
          instance_with_non_matching.should_not_receive(:terminate)

          instance_with_matching =
            instance_double('AWS::EC2::Instance', tags: { 'director' => 'fake-director-name' })
          instance_with_matching.stub(:status).and_return(:running, :terminated)
          instance_with_matching.should_receive(:terminate)

          microbosh_instance =
            instance_double('AWS::EC2::Instance', tags: { 'Name' => 'fake-director-name' })
          microbosh_instance.stub(:status).and_return(:running, :terminated)
          microbosh_instance.should_receive(:terminate)

          terminated_instance_with_matching =
            instance_double('AWS::EC2::Instance', tags: { 'director' => 'fake-director-name' }, status: :terminated)
          terminated_instance_with_matching.should_not_receive(:terminate)

          ec2.stub(instances: [
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
          ec2.stub(instances: [instance1, instance2])

          retryable = instance_double('Bosh::Retryable')
          Bosh::Retryable.stub(new: retryable)

          retryable.should_receive(:retryer) do |&blk|
            instance1.stub(status: :terminated)
            instance2.stub(status: :shutting_down)
            blk.call.should be(false)

            instance1.stub(status: :terminated)
            instance2.stub(status: :terminated)
            blk.call.should be(true)
          end

          instance1.stub(status: :running)
          instance2.stub(status: :running)
          micro_bosh_deployment_cleaner.clean
        end
      end

      context 'when matching instances are not found' do
        it 'finishes without waiting for anything' do
          ec2.stub(instances: [])
          micro_bosh_deployment_cleaner.clean
        end
      end
    end
  end
end
