require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::CloudManifestParser do
    subject(:parser) { described_class.new(logger) }
    let(:planner_attributes) {
      {
        name: 'deployment-name',
        properties: {}
      }
    }
    let(:event_log) { Config.event_log }
    let(:global_network_resolver) { instance_double(BD::DeploymentPlan::GlobalNetworkResolver, reserved_legacy_ranges: [])}
    let(:ip_provider_factory) { instance_double(BD::DeploymentPlan::IpProviderFactory, create: nil) }

    describe '#parse' do
      let(:parsed_cloud_planner) { subject.parse(cloud_manifest, ip_provider_factory, global_network_resolver) }
      let(:cloud_manifest) { Bosh::Spec::Deployments.simple_cloud_config }

      describe 'availability zones' do
        context 'when availability zones section is specified' do
          let(:availability_zones) {
            {'availability_zones' => [
              {'name' => 'z1',
                'cloud_properties' =>
                  {'availability_zone' =>
                    'us-east-1a'
                  }
              },
              {'name' => 'z2',
                'cloud_properties' =>
                  {'availability_zone' =>
                    'us-east-2a'
                  }
              }
            ]
            }
          }
          before { cloud_manifest.merge!(availability_zones) }

          context 'if name is not present' do
            let(:availability_zones) { {'availability_zones' => [{'cloud_properties' => {'availability_zone' => 'us-east-1a'}}]} }
            it 'raises error' do
              expect { parsed_cloud_planner }.to raise_error(ValidationMissingField)
            end
          end

          context 'if an availability zone is duplicated' do
            let(:availability_zones) { {'availability_zones' => [{'name' => 'z1'}, {'name' => 'z1'}]} }

            it 'raises error' do
              expect { parsed_cloud_planner }.to raise_error(DeploymentDuplicateAvailabilityZoneName, "Duplicate availability zone name `z1'")
            end
          end

          it 'creates AvailabilityZone for each entry' do
            expect(parsed_cloud_planner.availability_zone('z1').name).to eq('z1')
            expect(parsed_cloud_planner.availability_zone('z1').cloud_properties).to eq({'availability_zone' => 'us-east-1a'})
            expect(parsed_cloud_planner.availability_zone('z2').name).to eq('z2')
            expect(parsed_cloud_planner.availability_zone('z2').cloud_properties).to eq({'availability_zone' => 'us-east-2a'})
          end
        end
      end

      describe 'compilation' do
        context 'when compilation section is specified' do
          before do
            cloud_manifest.merge!('compilation' => {
                'network' => 'a',
                'cloud_properties' => {'super' => 'important'},
                'workers' => 3
              })
          end

          it 'parses the compilation section' do
            expect(parsed_cloud_planner.compilation.network_name).to eq('a')
            expect(parsed_cloud_planner.compilation.cloud_properties).to eq({'super' => 'important'})
          end
        end

        context 'when compilation section is not specified' do
          before { cloud_manifest.delete('compilation') }

          it 'raises an error' do
            expect {
              parsed_cloud_planner
            }.to raise_error(
                ValidationMissingField,
                /Required property `compilation' was not specified in object .+/,
              )
          end
        end

        context 'when compilation refers to a nonexistent network' do
          before do
            cloud_manifest.merge!('compilation' => {
                'network' => 'nonexistent-network',
                'cloud_properties' => {'super' => 'important'},
                'workers' => 3
              })
          end

          it 'raises an error' do
            expect {
              parsed_cloud_planner
            }.to raise_error(
                /unknown network `nonexistent-network'/,
              )
          end
        end
      end

      describe 'networks' do
        context 'when there is at least one network' do
          context 'when network type is not specified' do
            before do
              cloud_manifest.merge!(
                'networks' => [{
                    'name' => 'a',
                    'subnets' => [],
                  }])
            end

            it 'should create manual network by default' do
              expect(parsed_cloud_planner.networks.count).to eq(1)
              expect(parsed_cloud_planner.networks.first).to be_a(DeploymentPlan::ManualNetwork)
              expect(parsed_cloud_planner.networks.first.name).to eq('a')
            end
          end

          context 'when network type is manual' do
            context 'when an availability zone is specified for a subnet' do
              it 'validates that a zone with that name is present' do
                valid_manifest = cloud_manifest.merge({
                    'availability_zones' => [{'name' => 'fake-zone'}],
                    'networks' => [
                      {
                        'name' => 'a', #for compilation
                        'subnets' => []
                      },
                      {
                        'name' => 'fake-network',
                        'type' => 'manual',
                        'subnets' => [
                          {
                            'range' => '192.168.1.0/24',
                            'gateway' => '192.168.1.1',
                            'dns' => ['192.168.1.1', '192.168.1.2'],
                            'static' => ['192.168.1.10'],
                            'reserved' => [],
                            'cloud_properties' => {},
                            'availability_zone' => 'fake-zone'
                          }
                        ]
                      }]
                  })
                expect {
                  subject.parse(valid_manifest, ip_provider_factory, global_network_resolver)
                }.to_not raise_error
              end

              it 'errors if no zone with that name is present' do
                invalid_manifest = cloud_manifest.merge({
                    'availability_zones' => [{'name' => 'fake-zone'}],
                    'networks' => [{
                        'name' => 'fake-network',
                        'type' => 'manual',
                        'subnets' => [
                          {
                            'range' => '192.168.1.0/24',
                            'gateway' => '192.168.1.1',
                            'dns' => ['192.168.1.1', '192.168.1.2'],
                            'static' => ['192.168.1.10'],
                            'reserved' => [],
                            'cloud_properties' => {},
                            'availability_zone' => 'nonexistent-zone'
                          }
                        ]
                      }]
                  })

                expect {
                  subject.parse(invalid_manifest, ip_provider_factory, global_network_resolver)
                }.to raise_error(NetworkSubnetUnknownAvailabilityZone)
              end
            end
          end

          context 'when network type is dynamic'
          context 'when network type is vip'
          context 'when network type is unknown'

          context 'when more than one network have same canonical name' do
            before do
              cloud_manifest['networks'] = [
                { 'name' => 'bar', 'subnets' => [] },
                { 'name' => 'Bar', 'subnets' => [] },
              ]
            end

            it 'raises an error' do
              expect {
                parsed_cloud_planner
              }.to raise_error(
                  DeploymentCanonicalNetworkNameTaken,
                  "Invalid network name `Bar', canonical name already taken",
                )
            end
          end
        end

        context 'when 0 networks are specified' do
          before { cloud_manifest.merge!('networks' => []) }

          it 'raises an error because deployment must have at least one network' do
            expect {
              parsed_cloud_planner
            }.to raise_error(DeploymentNoNetworks, 'No networks specified')
          end
        end

        context 'when networks key is not specified' do
          before { cloud_manifest.delete('networks') }

          it 'raises an error because deployment must have at least one network' do
            expect {
              parsed_cloud_planner
            }.to raise_error(
                ValidationMissingField,
                /Required property `networks' was not specified in object .+/,
              )
          end
        end
      end

      describe 'resource_pools' do
        context 'when there is at least one resource_pool' do
          context 'when each resource pool has a unique name' do
            before do
              cloud_manifest['resource_pools'] = [
                Bosh::Spec::Deployments.resource_pool.merge('name' => 'rp1-name'),
                Bosh::Spec::Deployments.resource_pool.merge('name' => 'rp2-name')
              ]
            end

            it 'creates ResourcePools for each entry' do
              expect(parsed_cloud_planner.resource_pools.map(&:class)).to eq([DeploymentPlan::ResourcePool, DeploymentPlan::ResourcePool])
              expect(parsed_cloud_planner.resource_pools.map(&:name)).to eq(['rp1-name', 'rp2-name'])
            end

            it 'allows to look up resource_pool by name' do
              expect(parsed_cloud_planner.resource_pool('rp1-name').name).to eq('rp1-name')
              expect(parsed_cloud_planner.resource_pool('rp2-name').name).to eq('rp2-name')
            end
          end

          context 'when more than one resource pool have same name' do
            before do
              cloud_manifest['resource_pools'] = [
                Bosh::Spec::Deployments.resource_pool.merge({ 'name' => 'same-name' }),
                Bosh::Spec::Deployments.resource_pool.merge({ 'name' => 'same-name' })
              ]
            end

            it 'raises an error' do
              expect {
                parsed_cloud_planner
              }.to raise_error(
                  DeploymentDuplicateResourcePoolName,
                  "Duplicate resource pool name `same-name'",
                )
            end
          end
        end

        context 'when there are no resource pools' do
          before do
            cloud_manifest['resource_pools'] = []
          end

          it 'raises an error' do
            expect {
              parsed_cloud_planner
            }.to raise_error(
                DeploymentNoResourcePools,
                "No resource_pools specified",
              )
          end
        end
      end

      describe 'disk_pools' do
        context 'when there is at least one disk_pool' do
          context 'when each resource pool has a unique name' do
            before do
              cloud_manifest['disk_pools'] = [
                Bosh::Spec::Deployments.disk_pool.merge({ 'name' => 'dk1-name' }),
                Bosh::Spec::Deployments.disk_pool.merge({ 'name' => 'dk2-name' })
              ]
            end

            it 'creates DiskPools for each entry' do
              expect(parsed_cloud_planner.disk_pools.map(&:class)).to eq([DeploymentPlan::DiskPool, DeploymentPlan::DiskPool])
              expect(parsed_cloud_planner.disk_pools.map(&:name)).to eq(['dk1-name', 'dk2-name'])
            end

            it 'allows to look up disk_pool by name' do
              expect(parsed_cloud_planner.disk_pool('dk1-name').name).to eq('dk1-name')
              expect(parsed_cloud_planner.disk_pool('dk2-name').name).to eq('dk2-name')
            end
          end

          context 'when more than one disk pool have same name' do
            before do
              cloud_manifest['disk_pools'] = [
                Bosh::Spec::Deployments.disk_pool.merge({ 'name' => 'same-name' }),
                Bosh::Spec::Deployments.disk_pool.merge({ 'name' => 'same-name' })
              ]
            end

            it 'raises an error' do
              expect {
                parsed_cloud_planner
              }.to raise_error(
                  DeploymentDuplicateDiskPoolName,
                  "Duplicate disk pool name `same-name'",
                )
            end
          end
        end
      end
    end
  end
end
