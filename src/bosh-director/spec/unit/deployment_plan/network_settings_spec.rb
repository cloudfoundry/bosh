require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe NetworkSettings do
    let(:network_settings) do
      NetworkSettings.new(
        'fake-job',
        'fake-deployment',
        {'gateway' => 'net_a'},
        [reservation],
        {'net_a' => {'ip' => '10.0.0.6', 'netmask' => '255.255.255.0', 'gateway' => '10.0.0.1'}},
        az,
        3,
        'uuid-1'
      )
    end

    let(:az) { AvailabilityZone.new('az-1', {'foo' => 'bar'}) }
    let(:instance) { Instance.create_from_job(job, 3, 'started', plan, {}, az, logger) }
    let(:reservation) {
      reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance.model, manual_network)
      reservation.resolve_ip('10.0.0.6')
      reservation
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
            }]
        },
        [],
        GlobalNetworkResolver.new(plan, [], logger),
        logger
      )
    }
    let(:plan) { instance_double(Planner, using_global_networking?: true, name: 'fake-deployment') }

    describe '#network_settings' do
      let(:job) do
        job = InstanceGroup.new(logger)
        job.name = 'fake-job'
        job
      end

      context 'dynamic network' do
        let(:dynamic_network) do
          subnets = [DynamicNetworkSubnet.new(['1.2.3.4'], {'foo' => 'bar'}, 'az-1')]
          DynamicNetwork.new('net_a', subnets, logger)
        end

        let(:reservation) { Bosh::Director::DesiredNetworkReservation.new_dynamic(instance.model, dynamic_network) }

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

        describe '#network_address' do
          it 'returns the id based dns record address for the instance' do
            expect(network_settings.network_address).to eq('uuid-1.fake-job.net-a.fake-deployment.bosh')
          end
        end

        describe '#network_ip_address' do
          it 'returns the ip address for the instance' do
            expect(network_settings.network_ip_address).to eq('10.0.0.6')
          end
        end
      end

      context 'manual network' do
        describe '#network_address' do
          it 'returns the ip address for manual networks on the instance' do
            expect(network_settings.network_address).to eq('10.0.0.6')
          end
        end

        describe '#network_ip_address' do
          it 'returns the ip address for manual networks on the instance' do
            expect(network_settings.network_ip_address).to eq('10.0.0.6')
          end
        end
      end
    end
  end
end
