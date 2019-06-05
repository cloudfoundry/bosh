require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::CloudManifestParser do
    subject(:parser) { described_class.new(logger) }
    let(:planner_attributes) do
      {
        name: 'deployment-name',
        properties: {},
      }
    end
    let(:event_log) { Config.event_log }

    describe '#parse' do
      let(:parsed_cloud_planner) { subject.parse(cloud_manifest) }
      let(:cloud_manifest) { Bosh::Spec::NewDeployments.simple_cloud_config }

      context 'when availability zones section is specified' do
        describe 'availability zones' do
          let(:availability_zones) do
            {
              'azs' => [
                {
                  'name' => 'z1',
                  'cloud_properties' => {
                    'availability_zone' => 'us-east-1a',
                  },
                },
                {
                  'name' => 'z2',
                  'cloud_properties' => {
                    'availability_zone' => 'us-east-2a',
                  },
                  'cpi' => 'cpi1',
                },
              ],
            }
          end

          before { cloud_manifest.merge!(availability_zones) }

          it 'creates AvailabilityZone for each entry' do
            expect(parsed_cloud_planner.availability_zone('z1').name).to eq('z1')
            expect(parsed_cloud_planner.availability_zone('z1').cloud_properties).to eq('availability_zone' => 'us-east-1a')
            expect(parsed_cloud_planner.availability_zone('z1').cpi).to eq(nil)
            expect(parsed_cloud_planner.availability_zone('z2').name).to eq('z2')
            expect(parsed_cloud_planner.availability_zone('z2').cloud_properties).to eq('availability_zone' => 'us-east-2a')
            expect(parsed_cloud_planner.availability_zone('z2').cpi).to eq('cpi1')
          end
        end
      end

      describe 'compilation' do
        context 'when compilation section is specified' do
          before do
            cloud_manifest.merge!('compilation' => {
              'network' => 'a',
              'cloud_properties' => { 'super' => 'important' },
              'workers' => 3,
            })
          end

          it 'parses the compilation section' do
            expect(parsed_cloud_planner.compilation.network_name).to eq('a')
            expect(parsed_cloud_planner.compilation.cloud_properties).to eq('super' => 'important')
          end
        end

        context 'when compilation section is not specified' do
          before { cloud_manifest.delete('compilation') }

          it 'raises an error' do
            expect do
              parsed_cloud_planner
            end.to raise_error(
              ValidationMissingField,
              /Required property 'compilation' was not specified in object .+/,
            )
          end
        end

        context 'when compilation refers to a nonexistent network' do
          before do
            cloud_manifest.merge!('compilation' => {
              'network' => 'nonexistent-network',
              'cloud_properties' => { 'super' => 'important' },
              'workers' => 3,
            })
          end

          it 'raises an error' do
            expect do
              parsed_cloud_planner
            end.to raise_error(
              /unknown network 'nonexistent-network'/,
            )
          end
        end

        context 'when compilation refers to a network that does not have az that is specified in compilation' do
          before do
            cloud_manifest['compilation'] = {
              'network' => 'a',
              'cloud_properties' => { 'super' => 'important' },
              'workers' => 3,
              'az' => 'z1',
            }
            cloud_manifest['azs'] = [{ 'name' => 'z1' }, { 'name' => 'z2' }, { 'name' => 'z3' }]
            cloud_manifest['networks'].first['subnets'].first['azs'] = %w[z2 z3]
          end

          it 'raises an error' do
            expect do
              parsed_cloud_planner
            end.to raise_error(
              "Compilation config refers to az 'z1' but network 'a' has no matching subnet(s).",
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
                }],
              )
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
                valid_manifest = cloud_manifest.merge(
                  'azs' => [{ 'name' => 'fake-zone' }],
                  'networks' => [
                    {
                      'name' => 'a', # for compilation
                      'subnets' => [],
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
                          'az' => 'fake-zone',
                        },
                      ],
                    },
                  ],
                )
                expect do
                  subject.parse(valid_manifest)
                end.to_not raise_error
              end

              it 'errors if no zone with that name is present' do
                invalid_manifest = cloud_manifest.merge(
                  'azs' => [{ 'name' => 'fake-zone' }],
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
                        'az' => 'nonexistent-zone',
                      },
                    ],
                  }],
                )

                expect do
                  subject.parse(invalid_manifest)
                end.to raise_error(NetworkSubnetUnknownAvailabilityZone)
              end
            end
          end

          context 'when network type is dynamic' do
            context 'when an availability zone is specified for a subnet' do
              it 'validates that a zone with that name is present' do
                valid_manifest = cloud_manifest.merge(
                  'azs' => [{ 'name' => 'fake-zone' }],
                  'networks' => [
                    {
                      'name' => 'a', # for compilation
                      'subnets' => [],
                    },
                    {
                      'name' => 'fake-network',
                      'type' => 'dynamic',
                      'subnets' => [
                        {
                          'dns' => ['192.168.1.1', '192.168.1.2'],
                          'cloud_properties' => {},
                          'az' => 'fake-zone',
                        },
                      ],
                    },
                  ],
                )

                expect do
                  subject.parse(valid_manifest)
                end.to_not raise_error
              end

              it 'errors if no zone with that name is present' do
                invalid_manifest = cloud_manifest.merge(
                  'azs' => [{ 'name' => 'fake-zone' }],
                  'networks' => [{
                    'name' => 'fake-network',
                    'type' => 'dynamic',
                    'subnets' => [
                      {
                        'dns' => ['192.168.1.1', '192.168.1.2'],
                        'cloud_properties' => {},
                        'az' => 'nonexistent-zone',
                      },
                    ],
                  }],
                )

                expect do
                  subject.parse(invalid_manifest)
                end.to raise_error(NetworkSubnetUnknownAvailabilityZone)
              end
            end
          end

          context 'when network type is vip' do
            it 'parses the vip network' do
              valid_manifest = cloud_manifest.merge(
                'networks' => [
                  {
                    'name' => 'a', # for compilation
                    'subnets' => [],
                  },
                  {
                    'name' => 'vip-network',
                    'type' => 'vip',
                  },
                ],
              )

              expect do
                subject.parse(valid_manifest)
              end.to_not raise_error
            end
          end

          context 'when network type is unknown' do
            it 'raises an error' do
              valid_manifest = cloud_manifest.merge(
                'networks' => [
                  {
                    'name' => 'a', # for compilation
                    'subnets' => [],
                  },
                  {
                    'name' => 'unknown-network',
                    'type' => 'foobar',
                  },
                ],
              )

              expect do
                subject.parse(valid_manifest)
              end.to raise_error
            end
          end

          context 'when more than one network have same canonical name' do
            before do
              cloud_manifest['networks'] = [
                { 'name' => 'bar', 'subnets' => [] },
                { 'name' => 'Bar', 'subnets' => [] },
              ]
            end

            it 'raises an error' do
              expect do
                parsed_cloud_planner
              end.to raise_error(
                DeploymentCanonicalNetworkNameTaken,
                "Invalid network name 'Bar', canonical name already taken",
              )
            end
          end
        end

        context 'when 0 networks are specified' do
          before { cloud_manifest.merge!('networks' => []) }

          it 'raises an error because deployment must have at least one network' do
            expect do
              parsed_cloud_planner
            end.to raise_error(DeploymentNoNetworks, 'No networks specified')
          end
        end

        context 'when networks key is not specified' do
          before { cloud_manifest.delete('networks') }

          it 'raises an error because deployment must have at least one network' do
            expect do
              parsed_cloud_planner
            end.to raise_error(
              ValidationMissingField,
              /Required property 'networks' was not specified in object .+/,
            )
          end
        end
      end

      describe 'vm_types' do
        context 'when there is at least one vm_type' do
          context 'when each vm type has a unique name' do
            before do
              cloud_manifest['vm_types'] = [
                Bosh::Spec::NewDeployments.vm_type.merge('name' => 'vm1-name'),
                Bosh::Spec::NewDeployments.vm_type.merge('name' => 'vm2-name'),
              ]
            end

            it 'creates VmTypes for each entry' do
              expect(parsed_cloud_planner.vm_types.map(&:class)).to eq([DeploymentPlan::VmType, DeploymentPlan::VmType])
              expect(parsed_cloud_planner.vm_types.map(&:name)).to eq(['vm1-name', 'vm2-name'])
            end

            it 'allows to look up vm_type by name' do
              expect(parsed_cloud_planner.vm_type('vm1-name').name).to eq('vm1-name')
              expect(parsed_cloud_planner.vm_type('vm2-name').name).to eq('vm2-name')
            end
          end

          context 'when more than one vm type have same name' do
            before do
              cloud_manifest['vm_types'] = [
                Bosh::Spec::NewDeployments.vm_type.merge('name' => 'same-name'),
                Bosh::Spec::NewDeployments.vm_type.merge('name' => 'same-name'),
              ]
            end

            it 'raises an error' do
              expect do
                parsed_cloud_planner
              end.to raise_error(
                DeploymentDuplicateVmTypeName,
                "Duplicate vm type name 'same-name'",
              )
            end
          end
        end
      end

      describe 'vm_extensions' do
        context 'when vm_extensions are specified' do
          before do
            cloud_manifest['vm_extensions'] = [
              Bosh::Spec::NewDeployments.vm_extension.merge('name' => 'vm-extension-1-name'),
              Bosh::Spec::NewDeployments.vm_extension.merge('name' => 'vm-extension-2-name'),
            ]
          end

          it 'should create vmExtension for each entry' do
            expect(parsed_cloud_planner.vm_extensions.map(&:class))
              .to eq([DeploymentPlan::VmExtension, DeploymentPlan::VmExtension])
            expect(parsed_cloud_planner.vm_extensions.map(&:name)).to eq(['vm-extension-1-name', 'vm-extension-2-name'])
          end
        end
      end

      describe 'disk_types' do
        context 'when there is at least one disk_type' do
          context 'when each disk type has a unique name' do
            before do
              cloud_manifest['disk_types'] = [
                Bosh::Spec::NewDeployments.disk_type.merge('name' => 'dk1-name'),
                Bosh::Spec::NewDeployments.disk_type.merge('name' => 'dk2-name'),
              ]
            end

            it 'creates DiskTypes for each entry' do
              expect(parsed_cloud_planner.disk_types.map(&:class)).to eq([DeploymentPlan::DiskType, DeploymentPlan::DiskType])
              expect(parsed_cloud_planner.disk_types.map(&:name)).to eq(['dk1-name', 'dk2-name'])
            end

            it 'allows to look up disk_type by name' do
              expect(parsed_cloud_planner.disk_type('dk1-name').name).to eq('dk1-name')
              expect(parsed_cloud_planner.disk_type('dk2-name').name).to eq('dk2-name')
            end
          end

          context 'when more than one disk type have same name' do
            before do
              cloud_manifest['disk_types'] = [
                Bosh::Spec::NewDeployments.disk_type.merge('name' => 'same-name'),
                Bosh::Spec::NewDeployments.disk_type.merge('name' => 'same-name'),
              ]
            end

            it 'raises an error' do
              expect do
                parsed_cloud_planner
              end.to raise_error(
                DeploymentDuplicateDiskTypeName,
                "Duplicate disk type name 'same-name'",
              )
            end
          end
        end
      end
    end

    describe '#parse_availability_zones' do
      let(:parsed_availability_zones) { subject.parse_availability_zones(cloud_manifest) }
      let(:cloud_manifest) { Bosh::Spec::NewDeployments.simple_cloud_config }
      let(:availability_zones) do
        {
          'azs' => [
            {
              'name' => 'z1',
              'cloud_properties' => {
                'availability_zone' => 'us-east-1a',
              },
            },
            {
              'name' => 'z2',
              'cloud_properties' => {
                'availability_zone' => 'us-east-2a',
              },
              'cpi' => 'cpi1',
            },
          ],
        }
      end

      before { cloud_manifest.merge!(availability_zones) }

      context 'if name is not present' do
        let(:availability_zones) do
          { 'azs' => [{ 'cloud_properties' => { 'availability_zone' => 'us-east-1a' } }] }
        end
        it 'raises error' do
          expect { parsed_availability_zones }.to raise_error(ValidationMissingField)
        end
      end

      context 'if an availability zone is duplicated' do
        let(:availability_zones) do
          { 'azs' => [{ 'name' => 'z1' }, { 'name' => 'z1' }] }
        end

        it 'raises error' do
          expect { parsed_availability_zones }.to raise_error(DeploymentDuplicateAvailabilityZoneName, "Duplicate az name 'z1'")
        end
      end

      it 'returns an array of azs' do
        expect(parsed_availability_zones.size).to eq(2)
        expect(parsed_availability_zones.first).to be_a(DeploymentPlan::AvailabilityZone)
      end
    end
  end
end
