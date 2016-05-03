require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::GlobalNetworkResolver do
    subject(:global_network_resolver) { DeploymentPlan::GlobalNetworkResolver.new(current_deployment, logger) }

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


    describe '#reserved_legacy_ranges' do

      context 'when deploying with cloud config after legacy deployments' do
        let (:runtime_config){ nil }
        let(:cloud_config) do
          Models::CloudConfig.make({
            manifest: {
              'networks' => [{
                'name' => 'manual',
                'type' => 'manual',
                'subnets' => [
                  {
                    'range'=> '10.10.0.0/24',
                    'gateway' => '10.10.0.1',
                    'reserved' => ['10.10.0.1-10.10.0.10']
                  }
                ]
              }]
            }
          })
        end
        let(:runtime_config) { nil }

        it 'does not suck' do
          Models::Deployment.make(
            name: 'dummy1',
            cloud_config: nil,
            manifest: Psych.dump({
              'networks' => [{
                'name' => 'defaultA',
                'type' => 'manual',
                'subnets' => [{
                  'range' => '10.10.0.0/24',
                  'reserved' => ['10.10.0.1-10.10.0.10','10.10.0.20-10.10.0.255'],
                  'gateway'=> '10.10.0.1'
                }],
              }],
            })
          )
          Models::Deployment.make(
            name: 'dummy2',
            cloud_config: nil,
            manifest: Psych.dump({
              'networks' => [{
                'name' => 'defaultB',
                'type' => 'manual',
                'subnets' => [{
                  'range' => '10.10.0.0/24',
                  'reserved' => ['10.10.0.2-10.10.0.20','10.10.0.30-10.10.0.255'],
                  'gateway'=> '10.10.0.1'
                }],
              }],
            })
          )

          expect(global_network_resolver.reserved_legacy_ranges).not_to be_empty
        end
      end

      context 'when current deployment is using cloud config' do
        let(:cloud_config) { Models::CloudConfig.make }
        let(:runtime_config) { Models::RuntimeConfig.make }

        it 'excludes networks from deployments with cloud config' do
          Models::Deployment.make(
            name: 'other-deployment-1',
            cloud_config: cloud_config,
            runtime_config: runtime_config,
            manifest: Psych.dump({
                'networks' => [{
                    'name' => 'network-a',
                    'type' => 'manual',
                    'subnets' => [{
                        'range' => '192.168.0.0/24',
                      }],
                  }],
              })
          )
          reserved_ranges = global_network_resolver.reserved_legacy_ranges

          expect(reserved_ranges).to be_empty
        end

        context 'when have stale deployments' do
          before do
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
                      'range' => '192.168.0.0/28',
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
                      'range' => '192.168.1.0/24',
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
                    'range' => '192.168.2.0/24',
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

            Models::Deployment.make(
              name: 'other-deployment-4',
              cloud_config: cloud_config,
              runtime_config: nil,
              manifest: Psych.dump({
                'networks' => [{
                  'name' => 'network-a',
                  'type' => 'manual',
                  'subnets' => [{
                    'range' => '192.168.3.0/24',
                  }],
                }],
              })
            )
          end

          it 'returns manual network ranges from legacy deployments (deployments with no cloud config)' do
            reserved_ranges = global_network_resolver.reserved_legacy_ranges
            expect(reserved_ranges).to contain_exactly(
              NetAddr::CIDR.create('192.168.0.6/32'),
              NetAddr::CIDR.create('192.168.0.8/31'),
              NetAddr::CIDR.create('192.168.0.10/32'),
              NetAddr::CIDR.create('192.168.0.13/32'),
              NetAddr::CIDR.create('192.168.0.14/31'),
              NetAddr::CIDR.create('192.168.1.1/24'),
              NetAddr::CIDR.create('192.168.2.1/24'),
            )
          end

          it 'logs used ip address ranges in a nice format' do

            expect(logger).to receive(:info).with('Following networks and individual IPs are reserved by non-cloud-config deployments: ' +
                    '192.168.0.6, 192.168.0.8-192.168.0.10, 192.168.0.13-192.168.0.15, 192.168.1.0-192.168.2.255')
            global_network_resolver.reserved_legacy_ranges
          end
        end
        it "ignores deployments that don't have a manifest" do
          Models::Deployment.make(
            name: 'other-deployment',
            cloud_config: nil,
            runtime_config: nil,
            manifest: nil
          )

          reserved_ranges = global_network_resolver.reserved_legacy_ranges
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
          expect(global_network_resolver.reserved_legacy_ranges).to be_empty
        end
      end
    end
  end
end
