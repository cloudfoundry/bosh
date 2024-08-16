require 'spec_helper'

module Bosh::Director
  describe DnsEncoder do
    subject { described_class.new(service_groups, az_hash, short_dns_enabled, link_dns_enabled) }
    let(:az_hash) {}
    let(:short_dns_enabled) { false }
    let(:link_dns_enabled) { false }
    let(:group_name) { 'potato-group' }
    let(:default_network) { 'potato-net' }
    let(:default_network_id) { 1 }
    let(:deployment_name) { 'fake-deployment' }
    let(:root_domain) { 'sub.bosh' }
    let(:specific_query) do
      {}
    end
    let(:group_type_1) { 'group-type-1' }
    let(:group_type_2) { 'group-type-2' }

    let(:criteria) do
      {
        group_type: group_type_1,
        group_name: group_name,
        default_network: default_network,
        deployment_name: deployment_name,
        root_domain: root_domain,
      }.merge(specific_query)
    end

    let(:service_groups) do
      {
        {
          group_type: group_type_1,
          group_name: 'potato-group',
          deployment:     'fake-deployment',
        } => 3,
        {
          group_type: group_type_1,
          group_name: 'lemon-group',
          deployment:     'fake-deployment',
        } => 7,
        {
          group_type: group_type_2,
          group_name: 'lemon-group',
          deployment:     'fake-deployment',
        } => 10,
        {
          group_type: Models::LocalDnsEncodedGroup::Types::LINK,
          group_name: 'lemon-link-orange',
          deployment: 'fake-deployment',
        } => 12,
        {
          group_type: Models::LocalDnsEncodedGroup::Types::INSTANCE_GROUP,
          group_name: 'lemon-instance',
          deployment: 'fake-deployment',
        } => 13,
      }
    end

    before(:each) do
      FactoryBot.create(:models_local_dns_encoded_network, id: default_network_id, name: default_network)
      Models::Instance.make(id: 1, uuid: 'uuid-1')
    end

    describe '#encode_link' do
      let(:short_dns_enabled) { true } # links can *only* be encoded with short dns; disabled here as a reminder
      let(:link_dns_enabled) { true }
      let(:link_instance_group) { instance_double(DeploymentPlan::InstanceGroup, name: 'lemon-instance')}
      let(:link_def) do
        instance_double(
          DeploymentPlan::Link,
          provider_deployment_name: 'fake-deployment',
          provider_name: 'lemon-link',
          provider_type: 'orange',
          source_instance_group: link_instance_group,
        )
      end

      context 'link_dns_enabled is disabled' do
        let(:link_dns_enabled) { false }

        it 'uses instance group dns' do
          expect(subject.encode_link(link_def)).to eq('q-s0.q-g13.')
        end
      end

      it 'uses link group dns' do
        expect(subject.encode_link(link_def)).to eq('q-s0.q-g12.')
      end

      it 'accepts additional query criteria' do
        expect(subject.encode_link(link_def, status: 'healthy', default_network: default_network, root_domain: 'bosh'))
          .to eq("q-n#{default_network_id}s3.q-g12.bosh")
      end
    end

    describe '#encode_query' do
      context 'no filters' do
        it 'always includes health code in query with default healthy' do
          expect(subject.encode_query(criteria)).to eq('q-s0.potato-group.potato-net.fake-deployment.sub.bosh')
        end
      end

      describe 'initial_health_check' do
        context 'when synchronous' do
          let(:specific_query) do
            { initial_health_check: 'synchronous' }
          end

          it 'includes the initial health check in the query' do
            expect(subject.encode_query(criteria)).to eq('q-s0y1.potato-group.potato-net.fake-deployment.sub.bosh')
          end
        end

        context 'when asynchronous' do
          let(:specific_query) do
            { initial_health_check: 'asynchronous' }
          end

          it 'includes the initial health check in the query' do
            expect(subject.encode_query(criteria)).to eq('q-s0y0.potato-group.potato-net.fake-deployment.sub.bosh')
          end
        end
      end

      describe 'status' do
        context 'when default' do
          let(:specific_query) do
            { status: 'default' }
          end

          it 'includes the health code in the query' do
            expect(subject.encode_query(criteria)).to eq('q-s0.potato-group.potato-net.fake-deployment.sub.bosh')
          end
        end

        context 'when healthy' do
          let(:specific_query) do
            { status: 'healthy' }
          end

          it 'includes the health code in the query' do
            expect(subject.encode_query(criteria)).to eq('q-s3.potato-group.potato-net.fake-deployment.sub.bosh')
          end
        end

        context 'when unhealthy' do
          let(:specific_query) do
            { status: 'unhealthy' }
          end

          it 'includes the health code in the query' do
            expect(subject.encode_query(criteria)).to eq('q-s1.potato-group.potato-net.fake-deployment.sub.bosh')
          end
        end

        context 'when all' do
          let(:specific_query) do
            { status: 'all' }
          end

          it 'includes the health code in the query' do
            expect(subject.encode_query(criteria)).to eq('q-s4.potato-group.potato-net.fake-deployment.sub.bosh')
          end
        end

        context 'when it is an invalid value' do
          let(:specific_query) do
            { status: 'laksjdfl
              kasdfklasd' }
          end

          it 'includes the health code in the query' do
            expect(subject.encode_query(criteria)).to eq('q-s0.potato-group.potato-net.fake-deployment.sub.bosh')
          end
        end
      end

      describe 'individual instance query' do
        let(:specific_query) do
          { uuid: 'uuid-1' }
        end

        it 'includes uuid at start of name instead of q- syntax' do
          expect(subject.encode_query(criteria)).to eq('uuid-1.potato-group.potato-net.fake-deployment.sub.bosh')
        end
      end

      describe 'encoding AZ indices' do
        let(:az_hash) do
          { 'zone1' => '1', 'zone2' => '2' }
        end

        context 'single az filter' do
          let(:specific_query) do
            { azs: ['zone1'] }
          end
          it 'includes an a# code' do
            expect(subject.encode_query(criteria)).to eq('q-a1s0.potato-group.potato-net.fake-deployment.sub.bosh')
          end
        end

        context 'multiple az filter' do
          let(:specific_query) do
            { azs: %w[zone2 zone1] }
          end
          it 'includes all the codes in order' do
            expect(subject.encode_query(criteria)).to eq('q-a1a2s0.potato-group.potato-net.fake-deployment.sub.bosh')
          end
        end
      end

      describe 'short DNS names enabled by providing service groups' do
        let(:short_dns_enabled) { true }
        it 'produces an abbreviated address with three octets and a network' do
          expect(subject.encode_query(criteria)).to eq('q-n1s0.q-g3.sub.bosh')
        end

        context 'when desired group is not default' do
          let(:group_name) { 'lemon-group' }

          it 'chooses chooses correct service groups' do
            expect(subject.encode_query(criteria)).to eq('q-n1s0.q-g7.sub.bosh')
          end
        end

        context 'when including a UUID in the criteria' do
          let(:specific_query) do
            { uuid: 'uuid-1' }
          end
          it 'includes the m# code in the query' do
            expect(subject.encode_query(criteria)).to eq('q-m1n1s0.q-g3.sub.bosh')
          end
        end

        describe 'encoding network filter' do
          let(:default_network) { 'network1' }
          let(:default_network_id) { 4 }
          before(:each) do
            FactoryBot.create(:models_local_dns_encoded_network, id: 3, name: 'network2')
          end

          context 'default_network is set' do
            it 'includes an n# code' do
              expect(subject.encode_query(criteria)).to eq('q-n4s0.q-g3.sub.bosh')
            end
          end
        end
      end

      describe 'short DNS names are enabled' do
        let(:short_dns_enabled) { true }

        context 'and forcing query to not use short dns names' do
          it 'should return only long dns names' do
            expect(subject.encode_query(criteria, false)).to eq('q-s0.potato-group.potato-net.fake-deployment.sub.bosh')
          end
        end
      end

      describe 'short DNS names are disabled' do
        let(:short_dns_enabled) { false }

        context 'and forcing query to use short dns names' do
          it 'should return only short dns names' do
            expect(subject.encode_query(criteria, true)).to eq('q-n1s0.q-g3.sub.bosh')
          end
        end
      end
    end

    describe '#id_for_group_tuple' do
      context 'when short dns is enabled' do
        let(:short_dns_enabled) { true }
        it 'can look up the group id' do
          expect(
            subject.id_for_group_tuple(
              group_type_1,
              'potato-group',
              'fake-deployment',
            ),
          ).to eq '3'
          expect(
            subject.id_for_group_tuple(
              group_type_1,
              'lemon-group',
              'fake-deployment',
            ),
          ).to eq '7'
          expect(
            subject.id_for_group_tuple(
              group_type_2,
              'lemon-group',
              'fake-deployment',
            ),
          ).to eq '10'
        end
      end

      context 'even when short dns is not enabled' do
        it 'can still look up the group id' do
          expect(
            subject.id_for_group_tuple(
              group_type_1,
              'potato-group',
              'fake-deployment',
            ),
          ).to eq '3'
          expect(
            subject.id_for_group_tuple(
              group_type_1,
              'lemon-group',
              'fake-deployment',
            ),
          ).to eq '7'
          expect(
            subject.id_for_group_tuple(
              group_type_2,
              'lemon-group',
              'fake-deployment',
            ),
          ).to eq '10'
        end
      end
    end

    describe '#num_for_uuid' do
      before(:each) do
        Models::Instance.make(id: 2, uuid: 'uuid-2')
      end

      it 'matches if found' do
        expect(subject.num_for_uuid('uuid-1')).to eq('1')
        expect(subject.num_for_uuid('uuid-2')).to eq('2')
      end

      it 'raises exception if not found' do
        expect {
          subject.num_for_uuid('zone3')
        }.to raise_error(RuntimeError, "Unknown instance UUID: 'zone3'")
      end

      it 'returns nil if uuid is nil' do
        expect(subject.num_for_uuid(nil)).to eq(nil)
      end
    end

    describe '#id_for_az' do
      let(:az_hash) do
        { 'zone1' => '1', 'zone2' => '2' }
      end

      it 'matches if found' do
        expect(subject.id_for_az('zone1')).to eq('1')
        expect(subject.id_for_az('zone2')).to eq('2')
      end

      it 'raises exception if not found' do
        expect {
          subject.id_for_az('zone3')
        }.to raise_error(RuntimeError, "Unknown AZ: 'zone3'")
      end

      it 'returns nil if az is nil' do
        expect(subject.id_for_az(nil)).to eq(nil)
      end
    end

    describe '#id_for_network' do
      before(:each) do
        FactoryBot.create(:models_local_dns_encoded_network, id: 10, name: 'nw1')
        FactoryBot.create(:models_local_dns_encoded_network, id: 20, name: 'nw2')
      end

      it 'matches if found' do
        expect(subject.id_for_network('nw1')).to eq('10')
        expect(subject.id_for_network('nw2')).to eq('20')
      end

      it 'raises exception if not found' do
        expect {
          subject.id_for_network('nw3')
        }.to raise_error(RuntimeError, "Unknown Network: 'nw3'")
      end

      it 'returns nil if network name is nil' do
        expect(subject.id_for_network(nil)).to eq(nil)
      end
    end
  end
end
