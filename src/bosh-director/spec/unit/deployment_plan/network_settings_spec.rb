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
      )
    end
    let(:job) do
      job = InstanceGroup.new(logger)
      job.name = 'fake-job'
      job
    end

    let(:az) { AvailabilityZone.new('az-1', {'foo' => 'bar'}) }
    let(:instance) { Instance.create_from_job(job, 3, 'started', plan, {}, az, logger) }
    let(:reservations) {
      reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance.model, manual_network)
      reservation.resolve_ip('10.0.0.6')
      [reservation]
    }
    let(:manual_network) {
      ManualNetwork.parse({
          'name' => 'net_a',
          'dns' => ['1.2.3.4'],
          'subnets' => [{
              'range' => '10.0.0.1/24',
              'gateway' => '10.0.0.1',
              'dns' => ['1.2.3.4'],
              'cloud_properties' => {'foo' => 'bar'}
            }
          ]
        },
        [],
        GlobalNetworkResolver.new(plan, [], logger),
        logger
      )
    }
    let(:plan) { instance_double(Planner, using_global_networking?: true, name: 'fake-deployment') }

    describe '#to_hash' do
      context 'dynamic network' do
        let(:dynamic_network) do
          subnets = [DynamicNetworkSubnet.new(['1.2.3.4'], {'foo' => 'bar'}, 'az-1')]
          DynamicNetwork.new('net_a', subnets, logger)
        end

        let(:reservations) { [Bosh::Director::DesiredNetworkReservation.new_dynamic(instance.model, dynamic_network)] }

        it 'returns the network settings plus current IP, Netmask & Gateway from agent state' do
          expect(network_settings.to_hash).to eql({
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
          it 'returns the ip address for manual networks on the instance' do
            expect(network_settings.network_address).to eq('10.0.0.6')
          end
        end
      end
    end

    describe '#network_address' do
      context 'when it is a manual network' do
        context 'and local dns is disabled' do
          before do
            allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(false)
          end

          it 'returns the ip address for the instance' do
            expect(network_settings.network_address).to eq('10.0.0.6')
          end

          context 'when preferred network name is passed in' do
            let(:other_manual_network) {
              ManualNetwork.parse(
                {
                  'name' => 'net_b',
                  'dns' => ['5.6.7.8'],
                  'subnets' => [
                    {
                      'range' => '10.1.0.1/24',
                      'gateway' => '10.1.0.1',
                      'dns' => ['5.6.7.8'],
                      'cloud_properties' => {'waa' => 'too'}
                    }
                  ]
                },
                [],
                GlobalNetworkResolver.new(plan, [], logger),
                logger
              )
            }

            let(:reservations) do
              reservation_1 = Bosh::Director::DesiredNetworkReservation.new_static(instance.model, manual_network, '10.0.0.6')
              reservation_2 = Bosh::Director::DesiredNetworkReservation.new_static(instance.model, other_manual_network, '10.1.0.7')
              [reservation_1, reservation_2]
            end

            let(:options) { {:preferred_network_name => 'net_b'} }

            it 'returns the ip address for that network' do
              expect(network_settings.network_address(options)).to eq('10.1.0.7')
            end
          end
        end

        context 'when local dns is enabled' do
          before do
            allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(true)
          end

          context 'and a network is preferred' do
            let(:other_manual_network) {
              ManualNetwork.parse(
                {
                  'name' => 'net_b',
                  'dns' => ['5.6.7.8'],
                  'subnets' => [
                    {
                      'range' => '10.1.0.1/24',
                      'gateway' => '10.1.0.1',
                      'dns' => ['5.6.7.8'],
                      'cloud_properties' => {'waa' => 'too'}
                    }
                  ]
                },
                [],
                GlobalNetworkResolver.new(plan, [], logger),
                logger
              )
            }

            let(:reservations) do
              reservation_1 = Bosh::Director::DesiredNetworkReservation.new_static(instance.model, manual_network, '10.0.0.6')
              reservation_2 = Bosh::Director::DesiredNetworkReservation.new_static(instance.model, other_manual_network, '10.1.0.7')
              [reservation_1, reservation_2]
            end

            let(:options) { {:preferred_network_name => 'net_b'} }

            it 'returns the dns record for that network' do
              expect(network_settings.network_address(options)).to eq('uuid-1.fake-job.net-b.fake-deployment.bosh1.tld')
            end

            context 'and NOT explicitly requesting for ip' do
              let(:options) {
                {
                  :preferred_network_name => 'net_b',
                  :enforce_ip => false,
                }
              }

              it 'returns the dns record name of the instance' do
                expect(network_settings.network_address(options)).to eq('uuid-1.fake-job.net-b.fake-deployment.bosh1.tld')
              end
            end

            context 'and explicitly requesting for ip' do
              let(:options) {
                {
                  :preferred_network_name => 'net_b',
                  :enforce_ip => true,
                }
              }

              it 'returns the ip address of the instance' do
                expect(network_settings.network_address(options)).to eq('10.1.0.7')
              end
            end
          end

          context 'and there is no preferred network' do
            context 'and NOT explicitly requesting for ip' do
              let(:options) { {:enforce_ip => false, } }

              it 'returns the dns record name of the instance' do
                expect(network_settings.network_address(options)).to eq('uuid-1.fake-job.net-a.fake-deployment.bosh1.tld')
              end
            end

            context 'and explicitly requesting for ip' do
              let(:options) { {:enforce_ip => true, } }

              it 'returns the ip address of the instance' do
                expect(network_settings.network_address(options)).to eq('10.0.0.6')
              end
            end
          end
        end
      end

      context 'when it is a dynamic network' do
        let(:dynamic_network) do
          subnets = [DynamicNetworkSubnet.new(['1.2.3.4'], {'foo' => 'bar'}, 'az-1')]
          DynamicNetwork.new('net_a', subnets, logger)
        end
        let(:reservations) { [Bosh::Director::DesiredNetworkReservation.new_dynamic(instance.model, dynamic_network)] }

        context 'when local dns is disabled' do
          before do
            allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(false)
          end

          it 'returns the dns record name of the instance' do
            expect(network_settings.network_address).to eq('uuid-1.fake-job.net-a.fake-deployment.bosh1.tld')
          end
        end

        context 'when local dns is enabled' do
          before do
            allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(true)
          end

          it 'returns the dns record name of the instance' do
            expect(network_settings.network_address).to eq('uuid-1.fake-job.net-a.fake-deployment.bosh1.tld')
          end
        end

        context 'when preferred network name is passed in' do
          let(:other_dynamic_network) do
            subnets = [DynamicNetworkSubnet.new(['5.6.7.8'], {'waa' => 'hee'}, 'az-1')]
            DynamicNetwork.new('net_b', subnets, logger)
          end

          let(:reservations) {
            [
              Bosh::Director::DesiredNetworkReservation.new_dynamic(instance.model, dynamic_network),
              Bosh::Director::DesiredNetworkReservation.new_dynamic(instance.model, other_dynamic_network)
            ]
          }

          it 'returns the dns record for that specific network' do
            expect(network_settings.network_address(:preferred_network_name => 'net_b')).to eq('uuid-1.fake-job.net-b.fake-deployment.bosh1.tld')
          end
        end

        context 'when enforce_ip is set to true' do
          it 'neglects it and returns back DNS record name' do
            expect(network_settings.network_address(:enforce_ip => true)).to eq('uuid-1.fake-job.net-a.fake-deployment.bosh1.tld')
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
        let(:dynamic_network) do
          subnets = [DynamicNetworkSubnet.new(['1.2.3.4'], {'foo' => 'bar'}, 'az-1')]
          DynamicNetwork.new('net_a', subnets, logger)
        end

        let(:reservations) { [Bosh::Director::DesiredNetworkReservation.new_dynamic(instance.model, dynamic_network)] }

        it 'includes the network name and domain record' do
          expect(network_settings.network_addresses).to eq({
            'net_a' => 'uuid-1.fake-job.net-a.fake-deployment.bosh1.tld',
          })
        end
      end

      context 'manual network' do
        it 'includes the network name and ip' do
          expect(network_settings.network_addresses).to eq({
            'net_a' => '10.0.0.6',
          })
        end
      end
    end
  end
end
