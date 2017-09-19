require 'spec_helper'

module Bosh::Director
  describe LocalDnsEncoderManager do
    subject { described_class }

    describe '.persist_az_names' do
      it 'saves new AZs' do
        subject.persist_az_names(['zone1', 'zone2'])
        expect(Models::LocalDnsEncodedAz.all.count).to eq 2
        expect(Models::LocalDnsEncodedAz.all[0].name).to eq 'zone1'
        expect(Models::LocalDnsEncodedAz.all[0].id).to eq 1
        expect(Models::LocalDnsEncodedAz.all[1].name).to eq 'zone2'
        expect(Models::LocalDnsEncodedAz.all[1].id).to eq 2
      end

      it 'saves new AZs only if unique' do
        subject.persist_az_names(['zone1', 'zone2', 'zone1'])
        subject.persist_az_names(['zone1'])
        subject.persist_az_names(['zone2'])

        expect(Models::LocalDnsEncodedAz.all.count).to eq 2
        expect(Models::LocalDnsEncodedAz.all[0].name).to eq 'zone1'
        expect(Models::LocalDnsEncodedAz.all[0].id).to eq 1
        expect(Models::LocalDnsEncodedAz.all[1].name).to eq 'zone2'
        expect(Models::LocalDnsEncodedAz.all[1].id).to eq 2
      end
    end

    describe '.create_dns_encoder' do
      before do
        deployment = Models::Deployment.make(name: 'a-deployment')
        Models::LocalDnsEncodedAz.create(name: 'az1')
        net = Models::LocalDnsEncodedNetwork.create(name: 'my-network')
        ig = Models::LocalDnsEncodedInstanceGroup.create(name: 'some-ig', deployment_id: deployment.id)
        Models::LocalDnsServiceGroup.create(instance_group_id: ig.id, network_id: net.id)
      end

      it 'should create a dns encoder that uses the current index' do
        encoder = subject.create_dns_encoder
        expect(encoder.id_for_az('az1')).to eq('1')
        expect(encoder.id_for_group_tuple(
          'some-ig',
          'my-network',
          'a-deployment'
        )).to eq('1')
      end

      it 'respects the option for short names as default' do
        encoder = subject.create_dns_encoder
        expect(encoder.encode_query(
          instance_group: 'some-ig',
          default_network: 'my-network',
          deployment_name: 'a-deployment',
          root_domain: 'super-bosh'
        )).to eq 'q-s0.some-ig.my-network.a-deployment.super-bosh'
        encoder = subject.create_dns_encoder(true)
        expect(encoder.encode_query(
          instance_group: 'some-ig',
          default_network: 'my-network',
          deployment_name: 'a-deployment',
          root_domain: 'super-bosh'
        )).to eq 'q-s0.g-1.super-bosh'
      end
    end

    describe '.new_encoder_with_updated_index' do
      let(:plan) do
        instance_double(Bosh::Director::DeploymentPlan::Planner,
          name: 'new-deployment',
          availability_zones: [
            instance_double(Bosh::Director::DeploymentPlan::AvailabilityZone, name: 'new-az')
          ],
          instance_groups: [
            instance_double(Bosh::Director::DeploymentPlan::InstanceGroup,
              name: 'some-ig',
              networks: [
                instance_double(Bosh::Director::DeploymentPlan::Network, name: 'my-other-network'),
                instance_double(Bosh::Director::DeploymentPlan::Network, name: 'my-network')
              ]
            )
          ]
        )
      end

      before do
        Models::LocalDnsEncodedAz.create(name: 'old-az')
        deployment = Models::Deployment.make(name: 'old-deployment')
        net = Models::LocalDnsEncodedNetwork.create(name: 'my-network')
        ig = Models::LocalDnsEncodedInstanceGroup.create(name: 'some-ig', deployment_id: deployment.id)
        Models::LocalDnsServiceGroup.create(instance_group_id: ig.id, network_id: net.id)

        deployment2 = Models::Deployment.make(name: 'new-deployment')
        allow(plan).to receive(:model).and_return deployment2
      end

      it 'returns a dns encoder that includes the provided azs' do
        encoder = subject.new_encoder_with_updated_index(plan)
        expect(encoder.id_for_az('new-az')).to eq('2')
      end

      it 'returns an encoder that includes the provided groups' do
        encoder = subject.new_encoder_with_updated_index(plan)
        expect(encoder.id_for_group_tuple(
          'some-ig',
          'my-network',
          'new-deployment',
        )).to eq '3'
        expect(encoder.id_for_group_tuple(
          'some-ig',
          'my-other-network',
          'new-deployment',
        )).to eq '2'
      end
    end
  end
end
