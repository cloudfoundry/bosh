require 'spec_helper'
require 'bosh/director/deployment_plan/multi_instance_group_updater'
require 'bosh/director/instance_group_updater'

module Bosh::Director
  module DeploymentPlan::Stages
    describe CreateNetworkStage do
      before :each do
        allow(deployment_plan).to receive(:model).and_return(deployment_model)
        allow(deployment_plan).to receive(:instance_groups).and_return([instance_group])
        allow(instance_group).to receive(:networks).and_return([job_network])
        allow(job_network).to receive(:deployment_network).and_return(network)
        allow(network).to receive(:managed?).and_return(true)
        allow(AZCloudFactory).to receive(:create_with_latest_configs).and_return(cloud_factory)
        allow(cloud_factory).to receive(:get).and_return(cloud)
        allow(Config).to receive(:current_job).and_return(job)
        allow(job).to receive(:task_id).and_return(1)
        allow(job).to receive(:username).and_return('name')
        allow(Config).to receive(:network_lifecycle_enabled?).and_return(true)
      end

      subject { CreateNetworkStage.new(logger, deployment_plan) }
      let(:cloud_factory) { instance_double(AZCloudFactory) }
      let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
      let(:deployment_model) { FactoryBot.create(:models_deployment, name: 'deployment_name') }
      let(:job) { instance_double(Bosh::Director::Jobs::UpdateDeployment) }
      let(:job_network) { FactoryBot.build(:deployment_plan_job_network) }
      let(:instance_group) { instance_double(Bosh::Director::DeploymentPlan::InstanceGroup) }
      let(:deployment_plan) { instance_double(Bosh::Director::DeploymentPlan::Planner) }
      let(:availability_zone) { Bosh::Director::DeploymentPlan::AvailabilityZone.new('foo-az', 'old' => 'value') }

      context 'valid spec' do
        let(:network_spec) do
          {
            'name' => 'a',
            'type' => 'manual',
            'managed' => true,
            'subnets' => [
              {
                'name' => 'subnet-1',
                'range' => '192.168.10.0/24',
                'gateway' => '192.168.10.1',
                'cloud_properties' => { 't0_id' => '123456' },
                'dns' => ['8.8.8.8'],
              },
              {
                'name' => 'subnet-2',
                'range' => '192.168.20.0/24',
                'gateway' => '192.168.20.1',
                'cloud_properties' => { 't0_id' => '123456' },
                'dns' => ['8.8.8.8'],
              },
            ],
          }
        end

        let(:network) do
          Bosh::Director::DeploymentPlan::ManualNetwork.parse(
            network_spec,
            [availability_zone],
            logger,
          )
        end

        describe '#perform' do
          it 'creates all subnets successfully' do
            expect(cloud).to receive(:create_network).with(
              hash_including('gateway' => '192.168.10.1'),
            ).and_return(
              ['12345', {}, { name: 'dummy1' }],
            )
            expect(cloud).to receive(:create_network).with(
              hash_including('gateway' => '192.168.20.1'),
            ).and_return(
              ['67890', {}, { name: 'dummy2' }],
            )
            subject.perform

            expected_subnet_cidrs = network_spec['subnets'].map { |s| s['range'] }
            actual_subnet_cidrs = Bosh::Director::Models::Network.first(name: 'a').subnets.map(&:range)

            expect(actual_subnet_cidrs).to match_array(expected_subnet_cidrs)
          end

          it 'un-orphans the network is the network is orphaned' do
            expect(cloud).to receive(:create_network).with(
              hash_including('gateway' => '192.168.10.1'),
            ).and_return(
              ['12345', {}, { name: 'dummy1' }],
            )
            expect(cloud).to receive(:create_network).with(
              hash_including('gateway' => '192.168.20.1'),
            ).and_return(
              ['67890', {}, { name: 'dummy2' }],
            )
            subject.perform
            nw = Bosh::Director::Models::Network.first(name: 'a')
            nw.orphaned = true
            nw.save
            subject.perform
            nw = Bosh::Director::Models::Network.first(name: 'a')
            expect(nw.orphaned).to eq(false)
          end

          it 'does not create network in iaas if network already exists' do
            expect(cloud).to receive(:create_network).once.with(
              hash_including('gateway' => '192.168.10.1'),
            ).and_return(
              ['12345', {}, { name: 'dummy1' }],
            )
            expect(cloud).to receive(:create_network).once.with(
              hash_including('gateway' => '192.168.20.1'),
            ).and_return(
              ['67890', {}, { name: 'dummy2' }],
            )
            3.times do
              subject.perform
            end
          end

          it 'raises appropriate error when subnet is not found in the database' do
            expect(cloud).to receive(:create_network).once.with(
              hash_including('gateway' => '192.168.10.1'),
            ).and_return(
              ['12345', {}, { name: 'dummy1' }],
            )
            expect(cloud).to receive(:create_network).once.with(
              hash_including('gateway' => '192.168.20.1'),
            ).and_return(
              ['67890', {}, { name: 'dummy2' }],
            )

            subject.perform

            nw = Bosh::Director::Models::Network.first(name: 'a')
            subnet1 = nw.subnets.first
            subnet1.destroy
            nw.save
            expect { subject.perform }.to raise_error(Bosh::Director::SubnetNotFoundInDB)
          end

          it 'cleans up subnets on failure' do
            expect(cloud).to receive(:create_network).with(
              hash_including('gateway' => '192.168.10.1'),
            ).and_return(
              ['12345', {}, { name: 'dummy1' }],
            )
            expect(cloud).to receive(:create_network).with(
              hash_including('gateway' => '192.168.20.1'),
            ).and_raise('cpi error')
            expect(cloud).to receive(:delete_network).with('12345')
            expect { subject.perform }.to raise_error(/deployment failed during creating managed networks: cpi error/)
          end
        end
      end

      context 'subnet with no name' do
        let(:network_spec) do
          {
            'name' => 'a',
            'type' => 'manual',
            'managed' => true,
            'subnets' => [
              {
                'range' => '192.168.10.0/24',
                'gateway' => '192.168.10.1',
                'cloud_properties' => { 't0_id' => '123456' },
                'dns' => ['8.8.8.8'],
              },
              {
                'name' => 'subnet-2',
                'range' => '192.168.20.0/24',
                'gateway' => '192.168.20.1',
                'cloud_properties' => { 't0_id' => '123456' },
                'dns' => ['8.8.8.8'],
              },
            ],
          }
        end

        let(:network) do
          Bosh::Director::DeploymentPlan::ManualNetwork.parse(
            network_spec,
            [availability_zone],
            logger,
          )
        end

        describe '#perform' do
          it 'should fail when subnet has no name' do
            expect { subject.perform }.to raise_error(/subnet in managed network must have a name/)
          end
        end
      end

      context 'non unique subnets' do
        let(:network_spec) do
          {
            'name' => 'a',
            'type' => 'manual',
            'managed' => true,
            'subnets' => [
              {
                'name' => 'subnet-2',
                'range' => '192.168.10.0/24',
                'gateway' => '192.168.10.1',
                'cloud_properties' => { 't0_id' => '123456' },
                'dns' => ['8.8.8.8'],
              },
              {
                'name' => 'subnet-2',
                'range' => '192.168.20.0/24',
                'gateway' => '192.168.20.1',
                'cloud_properties' => { 't0_id' => '123456' },
                'dns' => ['8.8.8.8'],
              },
            ],
          }
        end

        let(:network) do
          Bosh::Director::DeploymentPlan::ManualNetwork.parse(
            network_spec,
            [availability_zone],
            logger,
          )
        end

        describe '#perform' do
          it 'should fail when subnet has a non unique name' do
            expect { subject.perform }.to raise_error(/subnet names within a managed network must be unique/)
          end
        end
      end
    end
  end
end
