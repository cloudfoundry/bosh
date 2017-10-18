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
    describe '.persist_network_names' do
      it 'saves new Networks' do
        subject.persist_network_names(['nw1', 'nw2'])
        expect(Models::LocalDnsEncodedNetwork.all.count).to eq 2
        expect(Models::LocalDnsEncodedNetwork.all[0].name).to eq 'nw1'
        expect(Models::LocalDnsEncodedNetwork.all[0].id).to eq 1
        expect(Models::LocalDnsEncodedNetwork.all[1].name).to eq 'nw2'
        expect(Models::LocalDnsEncodedNetwork.all[1].id).to eq 2
      end

      it 'saves new Networks only if unique' do
        subject.persist_network_names(['nw1', 'nw2', 'nw1'])
        subject.persist_network_names(['nw1'])
        subject.persist_network_names(['nw2'])

        expect(Models::LocalDnsEncodedNetwork.all.count).to eq 2
        expect(Models::LocalDnsEncodedNetwork.all[0].name).to eq 'nw1'
        expect(Models::LocalDnsEncodedNetwork.all[0].id).to eq 1
        expect(Models::LocalDnsEncodedNetwork.all[1].name).to eq 'nw2'
        expect(Models::LocalDnsEncodedNetwork.all[1].id).to eq 2
      end
    end

    describe '.create_dns_encoder' do
      before do
        deployment = Models::Deployment.make(name: 'a-deployment')
        Models::LocalDnsEncodedAz.create(name: 'az1')
        Models::LocalDnsEncodedInstanceGroup.create(name: 'some-ig', deployment_id: deployment.id)
        Models::LocalDnsEncodedNetwork.create(name: 'my-network')
        Models::Instance.make(deployment: deployment, id: 42, uuid: 'my-uuid')
      end

      it 'should create a dns encoder that uses the current index' do
        encoder = subject.create_dns_encoder(false)
        expect(encoder.id_for_az('az1')).to eq('1')
        expect(encoder.id_for_group_tuple(
          'some-ig',
          'a-deployment'
        )).to eq('1')
        expect(encoder.num_for_uuid('my-uuid')).to eq('42')
      end

      it 'respects the option for short names as default' do
        encoder = subject.create_dns_encoder(false)
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
        )).to eq 'q-n1s0.g-1.super-bosh'
      end
    end

    describe '.new_encoder_with_updated_index' do
      let(:plan) do
        instance_double(Bosh::Director::DeploymentPlan::Planner,
          name: 'new-deployment',
          use_short_dns_addresses?: false,
          availability_zones: [
            instance_double(Bosh::Director::DeploymentPlan::AvailabilityZone, name: 'new-az')
          ],
          networks: [
            instance_double(Bosh::Director::DeploymentPlan::Network, name: 'my-network'),
            instance_double(Bosh::Director::DeploymentPlan::Network, name: 'nw2')
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
        Models::LocalDnsEncodedInstanceGroup.create(name: 'some-ig', deployment_id: deployment.id)

        deployment2 = Models::Deployment.make(name: 'new-deployment')
        allow(plan).to receive(:model).and_return deployment2
      end

      it 'returns a dns encoder that includes the provided azs' do
        encoder = subject.new_encoder_with_updated_index(plan)
        expect(encoder.id_for_az('new-az')).to eq('2')
      end

      it 'returns a dns encoder that includes the provided networks' do
        encoder = subject.new_encoder_with_updated_index(plan)
        expect(encoder.id_for_network('nw2')).to eq('2')
      end


      it 'returns an encoder that includes the provided groups' do
        encoder = subject.new_encoder_with_updated_index(plan)
        expect(encoder.id_for_group_tuple(
          'some-ig',
          'new-deployment',
        )).to eq '2'
        expect(encoder.id_for_group_tuple(
          'some-ig',
          'old-deployment',
        )).to eq '1'
      end

      it 'respects the short-dns-names configuration in the plan' do
        allow(plan).to receive(:use_short_dns_addresses?).and_return false
        encoder = subject.new_encoder_with_updated_index(plan)
        expect(encoder.encode_query(
          instance_group: 'some-ig',
          deployment_name: 'new-deployment',
          default_network: 'my-network',
          root_domain: 'sub.bosh'
        )).to eq 'q-s0.some-ig.my-network.new-deployment.sub.bosh'

        allow(plan).to receive(:use_short_dns_addresses?).and_return true
        encoder = subject.new_encoder_with_updated_index(plan)
        expect(encoder.encode_query(
          instance_group: 'some-ig',
          deployment_name: 'new-deployment',
          default_network: 'my-network',
          root_domain: 'sub.bosh'
        )).to eq 'q-n1s0.g-2.sub.bosh'
      end
    end
  end
end
