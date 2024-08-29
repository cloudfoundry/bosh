require 'spec_helper'

module Bosh::Director
  describe LocalDnsEncoderManager do
    subject { described_class }

    describe '.persist_az_names' do
      it 'saves new AZs' do
        subject.persist_az_names(%w[zone1 zone2])
        expect(Models::LocalDnsEncodedAz.all.count).to eq 2
        expect(Models::LocalDnsEncodedAz.all[0].name).to eq 'zone1'
        expect(Models::LocalDnsEncodedAz.all[1].name).to eq 'zone2'
      end

      it 'saves new AZs only if unique' do
        subject.persist_az_names(%w[zone1 zone2 zone1])
        subject.persist_az_names(['zone1'])
        subject.persist_az_names(['zone2'])

        expect(Models::LocalDnsEncodedAz.all.count).to eq 2
        expect(Models::LocalDnsEncodedAz.all[0].name).to eq 'zone1'
        expect(Models::LocalDnsEncodedAz.all[1].name).to eq 'zone2'
      end
    end

    describe '.persist_network_names' do
      it 'saves new Networks' do
        subject.persist_network_names(%w[nw1 nw2])
        expect(Models::LocalDnsEncodedNetwork.all.count).to eq 2
        expect(Models::LocalDnsEncodedNetwork.all[0].name).to eq 'nw1'
        expect(Models::LocalDnsEncodedNetwork.all[1].name).to eq 'nw2'
      end

      it 'saves new Networks only if unique' do
        subject.persist_network_names(%w[nw1 nw2 nw1])
        subject.persist_network_names(['nw1'])
        subject.persist_network_names(['nw2'])

        expect(Models::LocalDnsEncodedNetwork.all.count).to eq 2
        expect(Models::LocalDnsEncodedNetwork.all[0].name).to eq 'nw1'
        expect(Models::LocalDnsEncodedNetwork.all[1].name).to eq 'nw2'
      end
    end

    describe '.create_dns_encoder' do
      let(:deployment) { FactoryBot.create(:models_deployment, name: 'a-deployment') }
      let(:encoder) { subject.create_dns_encoder(false) }
      let(:short_dns_encoder) { subject.create_dns_encoder(true) }

      before do
        Models::LocalDnsEncodedAz.create(name: 'az1')
        Models::LocalDnsEncodedGroup.create(
          name: 'some-ig',
          deployment_id: deployment.id,
          type: Models::LocalDnsEncodedGroup::Types::INSTANCE_GROUP,
        )
        Models::LocalDnsEncodedNetwork.create(name: 'my-network')
        FactoryBot.create(:models_instance, deployment: deployment, id: 7654321, uuid: 'my-uuid')

        # ensure we are efficiently loading deployments in the same query, not later queries
        expect(Bosh::Director::Models::LocalDnsEncodedGroup).to receive(:inner_join).at_least(:once).and_call_original
        expect(Bosh::Director::Models::Deployment).to_not receive(:primary_key_lookup)
      end

      it 'should create a dns encoder that uses the current index' do
        expect(encoder.id_for_az('az1')).to eq(Models::LocalDnsEncodedAz.last.id.to_s)
        expect(
          encoder.id_for_group_tuple(
            Models::LocalDnsEncodedGroup::Types::INSTANCE_GROUP,
            'some-ig',
            'a-deployment',
          ),
        ).to eq(Models::LocalDnsEncodedGroup.last.id.to_s)
        expect(encoder.num_for_uuid('my-uuid')).to eq('7654321')
      end

      it 'respects the option for short names as default' do
        expect(
          encoder.encode_query(
            group_type: Models::LocalDnsEncodedGroup::Types::INSTANCE_GROUP,
            group_name: 'some-ig',
            default_network: 'my-network',
            deployment_name: 'a-deployment',
            root_domain: 'super-bosh',
          ),
        ).to eq 'q-s0.some-ig.my-network.a-deployment.super-bosh'
        expect(
          short_dns_encoder.encode_query(
            group_type: Models::LocalDnsEncodedGroup::Types::INSTANCE_GROUP,
            group_name: 'some-ig',
            default_network: 'my-network',
            deployment_name: 'a-deployment',
            root_domain: 'super-bosh',
          ),
        ).to eq "q-n#{Models::LocalDnsEncodedNetwork.last.id}s0.q-g#{Models::LocalDnsEncodedGroup.last.id}.super-bosh"
      end
    end

    describe '.new_encoder_with_updated_index' do
      let(:plan) do
        instance_double(Bosh::Director::DeploymentPlan::Planner,
                        name: 'new-deployment',
                        use_short_dns_addresses?: false,
                        use_link_dns_names?: false,
                        availability_zones: [
                          instance_double(Bosh::Director::DeploymentPlan::AvailabilityZone, name: 'new-az'),
                        ],
                        networks: [
                          instance_double(Bosh::Director::DeploymentPlan::Network, name: 'my-network'),
                          instance_double(Bosh::Director::DeploymentPlan::Network, name: 'nw2'),
                        ],
                        instance_groups: [
                          instance_double(Bosh::Director::DeploymentPlan::InstanceGroup,
                                          name: 'some-ig',
                                          networks: [
                                            instance_double(Bosh::Director::DeploymentPlan::Network, name: 'my-other-network'),
                                            instance_double(Bosh::Director::DeploymentPlan::Network, name: 'my-network'),
                                          ]),
                        ])
      end

      let(:provider_intent1) { instance_double(Bosh::Director::Models::Links::LinkProviderIntent, group_name: 'provider1-t1') }
      let(:provider_intent2) { instance_double(Bosh::Director::Models::Links::LinkProviderIntent, group_name: 'provider2-t2') }
      let(:links_manager) do
        instance_double(
          Bosh::Director::Links::LinksManager,
          get_link_provider_intents_for_deployment: [provider_intent1, provider_intent2],
        )
      end

      before do
        Models::LocalDnsEncodedAz.create(name: 'old-az')
        deployment = FactoryBot.create(:models_deployment, name: 'old-deployment')
        Models::LocalDnsEncodedGroup.create(
          name: 'some-ig',
          deployment_id: deployment.id,
          type: Models::LocalDnsEncodedGroup::Types::INSTANCE_GROUP,
        )

        deployment2 = FactoryBot.create(:models_deployment, name: 'new-deployment')
        allow(plan).to receive(:model).and_return deployment2
        allow(plan).to receive(:links_manager).and_return(links_manager)
      end

      it 'returns a dns encoder that includes the provided azs' do
        encoder = subject.new_encoder_with_updated_index(plan)
        expect(encoder.id_for_az('new-az')).to eq(Models::LocalDnsEncodedAz.last.id.to_s)
      end

      it 'returns a dns encoder that includes the provided networks' do
        encoder = subject.new_encoder_with_updated_index(plan)
        expect(encoder.id_for_network('nw2')).to eq(Models::LocalDnsEncodedNetwork.last.id.to_s)
      end

      it 'returns an encoder that includes the provided groups' do
        encoder = subject.new_encoder_with_updated_index(plan)
        expect(
          encoder.id_for_group_tuple(
            Models::LocalDnsEncodedGroup::Types::INSTANCE_GROUP,
            'some-ig',
            'new-deployment',
          ),
        ).to eq Models::LocalDnsEncodedGroup.order(:id).all[1].id.to_s

        expect(
          encoder.id_for_group_tuple(
            Models::LocalDnsEncodedGroup::Types::INSTANCE_GROUP,
            'some-ig',
            'old-deployment',
          ),
        ).to eq Models::LocalDnsEncodedGroup.order(:id).all[0].id.to_s
        expect(
          encoder.id_for_group_tuple(
            Models::LocalDnsEncodedGroup::Types::LINK,
            'provider1-t1',
            'new-deployment',
          ),
        ).to eq Models::LocalDnsEncodedGroup.order(:id).all[2].id.to_s
        expect(
          encoder.id_for_group_tuple(
            Models::LocalDnsEncodedGroup::Types::LINK,
            'provider2-t2',
            'new-deployment',
          ),
        ).to eq Models::LocalDnsEncodedGroup.order(:id).all[3].id.to_s
      end

      it 'makes long dns names in the plan' do
        allow(plan).to receive(:use_short_dns_addresses?).and_return false
        encoder = subject.new_encoder_with_updated_index(plan)
        expect(
          encoder.encode_query(
            group_name: 'some-ig',
            deployment_name: 'new-deployment',
            default_network: 'my-network',
            root_domain: 'sub.bosh',
          ),
        ).to eq 'q-s0.some-ig.my-network.new-deployment.sub.bosh'

        expect(
          encoder.encode_query(
            group_name: 'link-provider1-t1',
            deployment_name: 'new-deployment',
            default_network: 'my-network',
            root_domain: 'sub.bosh',
          ),
        ).to eq 'q-s0.link-provider1-t1.my-network.new-deployment.sub.bosh'

        expect(
          encoder.encode_query(
            group_name: 'link-provider2-t2',
            deployment_name: 'new-deployment',
            default_network: 'my-network',
            root_domain: 'sub.bosh',
          ),
        ).to eq 'q-s0.link-provider2-t2.my-network.new-deployment.sub.bosh'
      end

      it 'makes short-dns-names in the plan' do
        allow(plan).to receive(:use_short_dns_addresses?).and_return true
        encoder = subject.new_encoder_with_updated_index(plan)
        expect(
          encoder.encode_query(
            group_name: 'some-ig',
            group_type: Models::LocalDnsEncodedGroup::Types::INSTANCE_GROUP,
            deployment_name: 'new-deployment',
            default_network: 'my-network',
            root_domain: 'sub.bosh',
          ),
        ).to eq "q-n#{Models::LocalDnsEncodedNetwork.first.id}s0.q-g#{Models::LocalDnsEncodedGroup.order(:id).all[1].id}.sub.bosh"

        expect(
          encoder.encode_query(
            group_name: 'provider1-t1',
            group_type: Models::LocalDnsEncodedGroup::Types::LINK,
            deployment_name: 'new-deployment',
            default_network: 'my-network',
            root_domain: 'sub.bosh',
          ),
        ).to eq "q-n#{Models::LocalDnsEncodedNetwork.first.id}s0.q-g#{Models::LocalDnsEncodedGroup.order(:id).all[2].id}.sub.bosh"

        expect(
          encoder.encode_query(
            group_name: 'provider2-t2',
            group_type: Models::LocalDnsEncodedGroup::Types::LINK,
            deployment_name: 'new-deployment',
            default_network: 'my-network',
            root_domain: 'sub.bosh',
          ),
        ).to eq "q-n#{Models::LocalDnsEncodedNetwork.first.id}s0.q-g#{Models::LocalDnsEncodedGroup.order(:id).all[3].id}.sub.bosh"
      end
    end
  end
end
