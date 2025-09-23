require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe NetworkSettings do
    let(:network_settings) do
      NetworkSettings.new(
        'fake-job',
        'fake-deployment',
        {'gateway' => 'net_a'},
        reservations,
        {'net_a' => {'ip' => '10.0.0.6', 'netmask' => '255.255.255.0', 'gateway' => '10.0.0.1'}},
        az,
        3,
        'uuid-1',
        'bosh1.tld',
        use_short_dns_addresses,
        use_link_dns_addresses,
      )
    end
    let(:instance_group) do
      instance_group = InstanceGroup.new(per_spec_logger)
      instance_group.name = 'fake-job'
      instance_group
    end

    let(:az) { AvailabilityZone.new('az-1', {'foo' => 'bar'}) }
    let(:reservations) do
      reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(nil, manual_network)
      reservation.resolve_ip('10.0.0.6')
      [reservation]
    end
    let(:manual_network) do
      ManualNetwork.parse(
        {
          'name' => 'net_a',
          'dns' => ['1.2.3.4'],
          'subnets' => [{
            'range' => '10.0.0.1/24',
            'gateway' => '10.0.0.1',
            'dns' => ['1.2.3.4'],
            'cloud_properties' => { 'foo' => 'bar' },
          }],
        },
        [],
        per_spec_logger,
      )
    end

    let(:plan) { instance_double(Planner, name: 'fake-deployment') }
    let(:use_short_dns_addresses) { false }
    let(:use_link_dns_addresses) { false }
    let(:dynamic_network) do
      subnets = [DynamicNetworkSubnet.new(['1.2.3.4'], {'foo' => 'bar'}, 'az-1', '32')]
      DynamicNetwork.new('net_a', subnets, '32', per_spec_logger)
    end

    before do
      allow_any_instance_of(Bosh::Director::DnsEncoder).to receive(:num_for_uuid)
        .with('uuid-1').and_return('1')
      allow_any_instance_of(Bosh::Director::DnsEncoder).to receive(:id_for_network)
        .with('net_a').and_return('1')
      allow_any_instance_of(Bosh::Director::DnsEncoder).to receive(:id_for_group_tuple)
        .with('instance-group', 'fake-job', 'fake-deployment').and_return('1')
    end

    describe '#to_hash' do
      context 'dynamic network' do
        let(:reservations) { [Bosh::Director::DesiredNetworkReservation.new_dynamic(nil, dynamic_network)] }

        it 'returns the network settings plus current IP, Netmask & Gateway from agent state' do
          expect(network_settings.to_hash).to eql(
            {
              'net_a' => {
                'type' => 'dynamic',
                'cloud_properties' => {
                  'foo' => 'bar'
                },
                'dns' => ['1.2.3.4'],
                'default' => ['gateway'],
                'ip' => '10.0.0.6',
                'netmask' => '255.255.255.0',
                'gateway' => '10.0.0.1'}
            })
        end
      end

      context 'manual network' do
        describe '#network_address' do
          let(:prefer_dns_addresses) { true }
          it 'returns the ip address for manual networks on the instance' do
            expect(network_settings.network_address(prefer_dns_addresses)).to eq('10.0.0.6')
          end
        end
      end
    end

    describe '#network_address' do
      context 'when prefer_dns_entry is set to true' do
        let(:prefer_dns_entry) {true}

        context 'when it is a manual network' do
          context 'and local dns is disabled' do
            before do
              allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(false)
            end

            it 'returns the ip address for the instance' do
              expect(network_settings.network_address(prefer_dns_entry)).to eq('10.0.0.6')
            end
          end

          context 'when local dns is enabled' do
            before do
              allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(true)
            end

            it 'returns the dns record for that network' do
              expect(network_settings.network_address(prefer_dns_entry)).to eq('uuid-1.fake-job.net-a.fake-deployment.bosh1.tld')
            end

            context 'when use_short_dns_addresses is true' do
              let(:use_short_dns_addresses) { true }

              it 'returns the short dns address' do
                expect(network_settings.network_address(prefer_dns_entry)).to eq('q-m1n1s0.q-g1.bosh1.tld')
              end
            end
          end
        end

        context 'when it is a dynamic network' do
          let(:reservations) {[Bosh::Director::DesiredNetworkReservation.new_dynamic(nil, dynamic_network)]}

          context 'when local dns is disabled' do
            before do
              allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(false)
            end

            it 'returns the dns record name of the instance' do
              expect(network_settings.network_address(prefer_dns_entry)).to eq('uuid-1.fake-job.net-a.fake-deployment.bosh1.tld')
            end
          end

          context 'when local dns is enabled' do
            before do
              allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(true)
            end

            it 'returns the dns record name of the instance' do
              expect(network_settings.network_address(prefer_dns_entry)).to eq('uuid-1.fake-job.net-a.fake-deployment.bosh1.tld')
            end
          end

          context 'when use_short_dns_addresses is true' do
            let(:use_short_dns_addresses) { true }
            it 'returns the short dns address' do
              expect(network_settings.network_address(prefer_dns_entry)).to eq('q-m1n1s0.q-g1.bosh1.tld')
            end
          end
        end
      end

      context 'when addressable is defined for a network' do
        let(:net_a) do
          {'ip' => '10.0.0.6', 'netmask' => '255.255.255.0', 'gateway' => '10.0.0.1'}
        end

        let(:net_public) do
          {'ip' => '10.0.0.7'}
        end

        let(:reservation) do
          network = ManualNetwork.parse(
            {
              'name' => 'net_public',
              'dns' => ['1.2.3.4'],
              'subnets' => [{
                              'range' => '10.0.0.0/24',
                              'gateway' => '10.0.0.1',
                              'dns' => ['1.2.3.4'],
                              'cloud_properties' => {'foo' => 'bar'}
                            }
              ]
            },
            [],
            per_spec_logger
          )
          Bosh::Director::DesiredNetworkReservation.new_dynamic(nil, network)
        end

        let(:reservations) do
          reservation.resolve_ip('10.0.0.7')
          [reservation]
        end

        let(:network_settings) do
          NetworkSettings.new(
            'fake-job',
            'fake-deployment',
            {'gateway' => 'net_a', 'addressable' => 'net_public'},
            reservations,
            {'net_a' => net_a, 'net_public' => net_public},
            az,
            3,
            'uuid-1',
            'bosh1.tld',
            false,
            false
          )
        end


        it 'returns the ip address of addressable network' do
          expect(network_settings.network_address(false)).to eq("10.0.0.7")
        end

        it 'returns the dns address of addressable network' do
          allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(true)
          expect(network_settings.network_address(true)).to eq('uuid-1.fake-job.net-public.fake-deployment.bosh1.tld')
        end
      end

      context 'when prefer_dns_entry is set to false' do
        let(:prefer_dns_entry) {false}

        context 'when it is a manual network' do
          context 'and local dns is disabled' do
            before do
              allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(false)
            end

            it 'returns the ip address for the instance' do
              expect(network_settings.network_address(prefer_dns_entry)).to eq('10.0.0.6')
            end
          end

          context 'when local dns is enabled' do
            before do
              allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(true)
            end

            it 'returns the ip address for the instance' do
              expect(network_settings.network_address(prefer_dns_entry)).to eq('10.0.0.6')
            end
          end
        end

        context 'when it is a dynamic network' do
          let(:reservations) {[Bosh::Director::DesiredNetworkReservation.new_dynamic(nil, dynamic_network)]}

          context 'when local dns is disabled' do
            before do
              allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(false)
            end

            it 'returns the dns record name of the instance' do
              expect(network_settings.network_address(prefer_dns_entry)).to eq('uuid-1.fake-job.net-a.fake-deployment.bosh1.tld')
            end
          end

          context 'when local dns is enabled' do
            before do
              allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(true)
            end

            it 'returns the dns record name of the instance' do
              expect(network_settings.network_address(prefer_dns_entry)).to eq('uuid-1.fake-job.net-a.fake-deployment.bosh1.tld')
            end
          end
        end
      end
    end

    describe '#dns_record_info' do
      it 'includes both id and uuid records' do
        expect(network_settings.dns_record_info).to eq({
          '3.fake-job.net-a.fake-deployment.bosh1.tld' => '10.0.0.6',
          'uuid-1.fake-job.net-a.fake-deployment.bosh1.tld' => '10.0.0.6',
        })
      end
    end

    describe '#network_addresses' do
      context 'dynamic network' do
        let(:reservations) {[Bosh::Director::DesiredNetworkReservation.new_dynamic(nil, dynamic_network)]}
        context 'when DNS entries are requested' do
          it 'includes the network name and domain record' do
            expect(network_settings.network_addresses(true)).to eq({'net_a' => 'uuid-1.fake-job.net-a.fake-deployment.bosh1.tld', })
          end
        end
        context 'when DNS entries are NOT requested' do
          it 'still includes the network name and domain record' do
            expect(network_settings.network_addresses(false)).to eq({'net_a' => 'uuid-1.fake-job.net-a.fake-deployment.bosh1.tld', })
          end
        end
      end

      context 'when network is manual' do
        context 'and local dns is disabled' do
          before do
            allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(false)
          end

          context 'and DNS entries are requested' do
            it 'includes the network name and ip' do
              expect(network_settings.network_addresses(true)).to eq({'net_a' => '10.0.0.6'})
            end
          end

          context 'and DNS entries are NOT requested' do
            it 'includes the network name and ip' do
              expect(network_settings.network_addresses(false)).to eq({'net_a' => '10.0.0.6'})
            end
          end
        end

        context 'and local dns is enabled' do
          before do
            allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(true)
          end

          context 'and DNS entries are requested' do
            it 'includes the network name dns record' do
              expect(network_settings.network_addresses(true)).to eq({'net_a' => 'uuid-1.fake-job.net-a.fake-deployment.bosh1.tld'})
            end
          end

          context 'and DNS entries are NOT requested' do
            it 'includes the network name dns record' do
              expect(network_settings.network_addresses(false)).to eq({'net_a' => '10.0.0.6'})
            end
          end
        end
      end
    end

    describe '#link_network_address' do
      let(:fake_encoder) { instance_double(Bosh::Director::DnsEncoder) }
      let(:link_def) { instance_double(Link) }

      before do
        allow(Bosh::Director::LocalDnsEncoderManager).to receive(:create_dns_encoder).and_return(fake_encoder)
      end

      context 'when DNS entries are requested' do
        context 'when it is a manual network' do
          context 'and local dns is disabled' do
            it 'returns the ip address for the instance' do
              allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(false)

              expect(network_settings.link_network_address(link_def, true)).to eq('10.0.0.6')
            end
          end

          context 'when local dns is enabled' do
            it 'returns the encoded DNS query for the link' do
              allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(true)

              expect(fake_encoder).to receive(:encode_link)
                .with(link_def, { root_domain: 'bosh1.tld', default_network: 'net_a', uuid: 'uuid-1' }).and_return('encoded-link')
              expect(network_settings.link_network_address(link_def, true)).to eq('encoded-link')
            end
          end
        end

        context 'when it is a dynamic network' do
          let(:dynamic_network) do
            subnets = [DynamicNetworkSubnet.new(['1.2.3.4'], { 'foo' => 'bar' }, 'az-1', '32')]
            DynamicNetwork.new('net_a', subnets, '32', per_spec_logger)
          end
          let(:reservations) { [Bosh::Director::DesiredNetworkReservation.new_dynamic(nil, dynamic_network)] }

          context 'when local dns is disabled' do
            it 'returns the encoded DNS query for the link' do
              allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(false)

              expect(fake_encoder).to receive(:encode_link)
                .with(link_def, { root_domain: 'bosh1.tld', default_network: 'net_a', uuid: 'uuid-1' }).and_return('encoded-link')
              expect(network_settings.link_network_address(link_def, true)).to eq('encoded-link')
            end
          end

          context 'when local dns is enabled' do
            it 'returns the encoded DNS query for the link' do
              allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(true)

              expect(fake_encoder).to receive(:encode_link)
                .with(link_def, { root_domain: 'bosh1.tld', default_network: 'net_a', uuid: 'uuid-1' }).and_return('encoded-link')
              expect(network_settings.link_network_address(link_def, true)).to eq('encoded-link')
            end
          end
        end
      end

      context 'when addressable is defined for a network' do
        let(:net_a) do
          { 'ip' => '10.0.0.6', 'netmask' => '255.255.255.0', 'gateway' => '10.0.0.1' }
        end

        let(:net_public) do
          { 'ip' => '10.0.0.7' }
        end

        let(:reservation) do
          network = ManualNetwork.parse(
            {
              'name' => 'net_public',
              'dns' => ['1.2.3.4'],
              'subnets' => [
                {
                  'range' => '10.0.0.0/24',
                  'gateway' => '10.0.0.1',
                  'dns' => ['1.2.3.4'],
                  'cloud_properties' => { 'foo' => 'bar' },
                },
              ],
            },
            [],
            per_spec_logger,
          )
          Bosh::Director::DesiredNetworkReservation.new_dynamic(nil, network)
        end

        let(:reservations) do
          reservation.resolve_ip('10.0.0.7')
          [reservation]
        end

        let(:network_settings) do
          NetworkSettings.new(
            'fake-job',
            'fake-deployment',
            { 'gateway' => 'net_a', 'addressable' => 'net_public' },
            reservations,
            { 'net_a' => net_a, 'net_public' => net_public },
            az,
            3,
            'uuid-1',
            'bosh1.tld',
            false,
            false,
          )
        end

        context 'and DNS addresses are not requested' do
          it 'returns the ip address of addressable network' do
            expect(network_settings.link_network_address(link_def, false)).to eq('10.0.0.7')
          end
        end

        context 'and DNS addresses are requested' do
          it 'returns the encoded query for the link with the public address' do
            allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(true)
            expect(fake_encoder).to receive(:encode_link)
              .with(link_def, { root_domain: 'bosh1.tld', default_network: 'net_public', uuid: 'uuid-1' }).and_return('encoded-link')
            expect(network_settings.link_network_address(link_def, true)).to eq('encoded-link')
          end
        end
      end

      context 'when prefer_dns_entry is set to false' do
        context 'when it is a manual network' do
          context 'and local dns is disabled' do
            it 'returns the ip address for the instance' do
              allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(false)

              expect(network_settings.link_network_address(link_def, false)).to eq('10.0.0.6')
            end
          end

          context 'when local dns is enabled' do
            it 'returns the ip address for the instance' do
              allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(true)

              expect(network_settings.link_network_address(link_def, false)).to eq('10.0.0.6')
            end
          end
        end

        context 'when it is a dynamic network' do
          let(:dynamic_network) do
            subnets = [DynamicNetworkSubnet.new(['1.2.3.4'], { 'foo' => 'bar' }, 'az-1', '32')]
            DynamicNetwork.new('net_a', subnets, '32', per_spec_logger)
          end
          let(:reservations) { [Bosh::Director::DesiredNetworkReservation.new_dynamic(nil, dynamic_network)] }

          context 'when local dns is disabled' do
            it 'returns the dns record name of the instance' do
              allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(false)

              expect(fake_encoder).to receive(:encode_link)
                .with(link_def, { root_domain: 'bosh1.tld', default_network: 'net_a', uuid: 'uuid-1' }).and_return('encoded-link')
              expect(network_settings.link_network_address(link_def, true)).to eq('encoded-link')
            end
          end

          context 'when local dns is enabled' do
            it 'returns the dns record name of the instance' do
              allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(true)

              expect(fake_encoder).to receive(:encode_link)
                .with(link_def, { root_domain: 'bosh1.tld', default_network: 'net_a', uuid: 'uuid-1' }).and_return('encoded-link')
              expect(network_settings.link_network_address(link_def, true)).to eq('encoded-link')
            end
          end
        end
      end
    end

    describe '#link_network_addresses' do
      let(:link_def) { instance_double(Link) }
      let(:fake_encoder) { instance_double(Bosh::Director::DnsEncoder) }

      before do
        allow(Bosh::Director::LocalDnsEncoderManager).to receive(:create_dns_encoder).and_return(fake_encoder)
      end

      context 'when there are multiple network reservations' do
        let(:dynamic_network) do
          subnets = [DynamicNetworkSubnet.new(['1.2.3.4'], { 'foo' => 'bar' }, 'az-1', '32')]
          DynamicNetwork.new('net_a', subnets, '32', per_spec_logger)
        end

        let(:dynamic_network2) do
          subnets = [DynamicNetworkSubnet.new(['9.8.7.6'], { 'bob' => 'joe' }, 'az-1', '32')]
          DynamicNetwork.new('net_b', subnets, '32', per_spec_logger)
        end

        let(:reservations) do
          [
            Bosh::Director::DesiredNetworkReservation.new_dynamic(nil, dynamic_network),
            Bosh::Director::DesiredNetworkReservation.new_dynamic(nil, dynamic_network2),
          ]
        end

        it 'will return the correct address for each reservation' do
          expect(fake_encoder).to receive(:encode_link)
            .with(link_def, { root_domain: 'bosh1.tld', default_network: 'net_a', uuid: 'uuid-1' })
            .and_return('encoded-query')
          expect(fake_encoder).to receive(:encode_link)
            .with(link_def, { root_domain: 'bosh1.tld', default_network: 'net_b', uuid: 'uuid-1' })
            .and_return('encoded-query-b')
          expect(network_settings.link_network_addresses(link_def, true))
            .to eq('net_a' => 'encoded-query', 'net_b' => 'encoded-query-b')
        end
      end

      context 'dynamic network' do
        let(:dynamic_network) do
          subnets = [DynamicNetworkSubnet.new(['1.2.3.4'], { 'foo' => 'bar' }, 'az-1', '32')]
          DynamicNetwork.new('net_a', subnets, '32', per_spec_logger)
        end

        let(:reservations) { [Bosh::Director::DesiredNetworkReservation.new_dynamic(nil, dynamic_network)] }

        context 'when DNS entries are requested' do
          it 'includes the network name and encoded query for the link address' do
            expect(fake_encoder).to receive(:encode_link)
              .with(link_def, { root_domain: 'bosh1.tld', default_network: 'net_a', uuid: 'uuid-1' })
              .and_return('encoded-query')
            expect(network_settings.link_network_addresses(link_def, true)).to eq('net_a' => 'encoded-query')
          end
        end

        context 'when DNS entries are NOT requested' do
          it 'still includes the network name and encoded query for the link address' do
            expect(fake_encoder).to receive(:encode_link)
              .with(link_def, { root_domain: 'bosh1.tld', default_network: 'net_a', uuid: 'uuid-1' })
              .and_return('encoded-query')
            expect(network_settings.link_network_addresses(link_def, false)).to eq('net_a' => 'encoded-query')
          end
        end
      end

      context 'when network is manual' do
        context 'and local dns is disabled' do
          before do
            allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(false)
          end

          context 'and DNS entries are requested' do
            it 'includes the network name and ip' do
              expect(network_settings.link_network_addresses(link_def, true)).to eq('net_a' => '10.0.0.6')
            end
          end

          context 'and DNS entries are NOT requested' do
            it 'includes the network name and ip' do
              expect(network_settings.link_network_addresses(link_def, false)).to eq('net_a' => '10.0.0.6')
            end
          end
        end

        context 'and local dns is enabled' do
          before do
            allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(true)
          end

          context 'and DNS entries are requested' do
            it 'includes the network name dns record' do
              expect(fake_encoder).to receive(:encode_link)
                .with(link_def, { root_domain: 'bosh1.tld', default_network: 'net_a', uuid: 'uuid-1' })
                .and_return('encoded-query')
              expect(network_settings.link_network_addresses(link_def, true)).to eq('net_a' => 'encoded-query')
            end
          end

          context 'and DNS entries are NOT requested' do
            it 'includes the network name dns record' do
              expect(network_settings.link_network_addresses(link_def, false)).to eq('net_a' => '10.0.0.6')
            end
          end
        end
      end
    end
  end
end
