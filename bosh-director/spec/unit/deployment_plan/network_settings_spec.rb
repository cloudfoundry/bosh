require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe NetworkSettings do
    let(:network_settings) do
      NetworkSettings.new(
        'fake-job',
        is_errand,
        'fake-deployment',
        {},
        [reservation],
        {'networks' =>
          {'net_a' => {'ip' => '10.0.0.6', 'netmask' => '255.255.255.0', 'gateway' => '10.0.0.1'}}
        },
        az,
        3,
        'uuid-1'
      )
    end

    let(:az) { AvailabilityZone.new('az-1', {'foo' => 'bar'}) }
    let(:instance) { Instance.new(job, 3, 'started', plan, {}, az, false, logger) }
    let(:reservation) {
      reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance, manual_network)
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
        GlobalNetworkResolver.new(plan),
        logger
      )
    }
    let(:is_errand) { false }
    let(:plan) { instance_double(Planner, using_global_networking?: true, name: 'fake-deployment') }
    before { allow(Bosh::Director::Config).to receive(:dns_domain_name).and_return('test_domain') }

    describe '#network_settings' do
      let(:job) do
        instance_double(Job, {
            deployment: plan,
            name: 'fake-job',
            can_run_as_errand?: false,
          })
      end

      context 'dynamic network' do
        let(:dynamic_network) do
          subnets = [DynamicNetworkSubnet.new(['1.2.3.4'], {'foo' => 'bar'}, 'az-1')]
          DynamicNetwork.new('net_a', subnets, logger)
        end

        let(:reservation) { Bosh::Director::DesiredNetworkReservation.new_dynamic(instance, dynamic_network) }

        it 'returns the network settings plus current IP, Netmask & Gateway from agent state' do
          expect(network_settings.to_hash).to eql({
                'net_a' => {
                  'type' => 'dynamic',
                  'cloud_properties' => {
                    'foo' => 'bar'
                  },
                  'dns' => ['1.2.3.4'],
                  'dns_record_name' => '3.fake-job.net-a.fake-deployment.test_domain',
                  'ip' => '10.0.0.6',
                  'netmask' => '255.255.255.0',
                  'gateway' => '10.0.0.1'}
              })
        end

        describe '#network_addresses' do
          it 'returns the id based dns record address for the instance' do
            expect(network_settings.network_addresses).to eq({
                  'net_a' => {'address' => 'uuid-1.fake-job.net-a.fake-deployment.test_domain'}
                })
          end
        end
      end

      context 'manual network' do
        describe '#network_addresses' do
          it 'returns the ip addresses for manual networks on the instance' do
            expect(network_settings.network_addresses).to eq({
                  'net_a' => {'address' => '10.0.0.6'}
                })
          end
        end
      end

      describe 'temporary errand hack' do
        context 'when job is not an errand' do
          it 'includes index based dns_record_name' do
            #retaining the index based dns name so as not to cause vm recreation
            #at some point the apply spec will not diff based on this record name, and we can recreate it.
            expect(network_settings.to_hash['net_a']['dns_record_name']).to eq('3.fake-job.net-a.fake-deployment.test_domain')
          end
        end

        context 'when job is an errand' do
          let(:is_errand) { true }
          it 'does not include dns_record_name' do
            expect(network_settings.to_hash['net_a']).to_not have_key('dns_record_name')
          end
        end
      end
    end
  end
end
