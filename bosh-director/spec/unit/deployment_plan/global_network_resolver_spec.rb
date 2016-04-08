require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::GlobalNetworkResolver do
    subject(:global_network_resolver) { DeploymentPlan::GlobalNetworkResolver.new(current_deployment) }

    let(:current_deployment) do
      deployment_model = Models::Deployment.make(
        name: 'current-deployment',
        cloud_config: cloud_config,
        runtime_config: runtime_config
      )
      DeploymentPlan::Planner.new(
        {name: 'current-deployment', properties: {}},
        '',
        cloud_config,
        runtime_config,
        deployment_model
      )
    end

    describe 'reserved_legacy_networks' do
      context 'when current deployment is using cloud config' do
        let(:cloud_config) { Models::CloudConfig.make }
        let(:runtime_config) { Models::RuntimeConfig.make }

        it 'returns manual network ranges with the same name from legacy deployments' do
          Models::Deployment.make(
            name: 'other-deployment-1',
            cloud_config: nil,
            runtime_config: nil,
            manifest: Psych.dump({
              'networks' => [
                {
                  'name' => 'network-a',
                  'type' => 'manual',
                  'subnets' => [{
                    'range' => '192.168.0.1/28',
                    'reserved' => [
                      '192.168.0.0-192.168.0.5',
                      '192.168.0.7',
                      '192.168.0.11-192.168.0.12'
                    ],
                  }],
                },
                {
                  'name' => 'network-b',
                  'type' => 'manual',
                  'subnets' => [{
                    'range' => '192.168.1.1/24',
                  }],
                }
              ],
            })
          )

          Models::Deployment.make(
            name: 'other-deployment-2',
            cloud_config: nil,
            runtime_config: nil,
            manifest: Psych.dump({
                'networks' => [{
                    'name' => 'network-a',
                    'type' => 'manual',
                    'subnets' => [{
                        'range' => '192.168.2.1/24',
                      }],
                  }],
              })
          )

          Models::Deployment.make(
            name: 'other-deployment-3',
            cloud_config: nil,
            runtime_config: nil,
            manifest: Psych.dump({
                'networks' => [{
                    'name' => 'network-a',
                    'type' => 'dynamic',
                  }],
              })
          )

          reserved_ranges = global_network_resolver.reserved_legacy_ranges('network-a')

          expect(reserved_ranges).to contain_exactly(
            NetAddr::CIDR.create('192.168.0.6/32'),
            NetAddr::CIDR.create('192.168.0.8/31'),
            NetAddr::CIDR.create('192.168.0.10/32'),
            NetAddr::CIDR.create('192.168.0.13/32'),
            NetAddr::CIDR.create('192.168.0.14/31'),
            NetAddr::CIDR.create('192.168.2.1/24')
          )
        end

        it "ignores deployments that don't have a manifest" do
          Models::Deployment.make(
            name: 'other-deployment',
            cloud_config: nil,
            runtime_config: nil,
            manifest: nil
          )

          reserved_ranges = global_network_resolver.reserved_legacy_ranges('network-a')
          expect(reserved_ranges).to be_empty
        end

        it 'does not return networks with the same name from migrated deployments' do
          Models::Deployment.make(
            name: 'other-deployment-1',
            cloud_config: cloud_config,
            runtime_config: runtime_config,
            manifest: Psych.dump({
                'networks' => [{
                    'name' => 'network-a',
                    'type' => 'manual',
                    'subnets' => [{
                        'range' => '192.168.0.1/24',
                      }],
                  }],
              })
          )
          reserved_ranges = global_network_resolver.reserved_legacy_ranges('network-a')
          expect(reserved_ranges).to be_empty
        end
      end

      context 'when current deployment is not using cloud config' do
        let(:cloud_config) { nil }
        let(:runtime_config) { nil }

        before do
          Models::Deployment.make(
            name: 'other-deployment',
            cloud_config: nil,
            runtime_config: nil,
            manifest: Psych.dump({
                'networks' => [{
                    'name' => 'network-a',
                    'type' => 'manual',
                    'subnets' => [{
                        'range' => '192.168.2.1/24',
                      }],
                  }],
              })
          )
        end

        it 'is empty' do
          expect(global_network_resolver.reserved_legacy_ranges(('network-a'))).to be_empty
        end
      end
    end
  end
end
