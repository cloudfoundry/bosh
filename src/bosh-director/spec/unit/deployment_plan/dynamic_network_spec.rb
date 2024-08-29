require 'spec_helper'

describe Bosh::Director::DeploymentPlan::DynamicNetwork do

  let(:logger) { Logging::Logger.new('TestLogger') }
  let(:instance) { instance_double(Bosh::Director::DeploymentPlan::Instance, model: instance_model) }
  let(:instance_model) { FactoryBot.create(:models_instance) }

  describe '.parse' do
    context 'with a manifest using the old format without explicit subnets' do
      it 'parses the spec and creates a subnet from the dns and cloud properties' do
        network = Bosh::Director::DeploymentPlan::DynamicNetwork.parse(
          {
            'name' => 'foo',
            'dns' => %w[1.2.3.4 5.6.7.8],
            'cloud_properties' => {'foz' => 'baz'},
          },
          [Bosh::Director::DeploymentPlan::AvailabilityZone.new('foo-zone', {})],
          logger
        )

        expect(network.name).to eq('foo')
        expect(network.subnets.length).to eq(1)
        expect(network.subnets.first.dns).to eq(['1.2.3.4', '5.6.7.8'])
        expect(network.subnets.first.cloud_properties).to eq({'foz' => 'baz'})
        expect(network.subnets.first.availability_zone_names).to eq(nil)
      end

      it 'defaults cloud properties to empty hash' do
        network = Bosh::Director::DeploymentPlan::DynamicNetwork.parse(
          {
            'name' => 'foo',
          },
          [],
          logger
        )
        expect(network.subnets.length).to eq(1)
        expect(network.subnets.first.cloud_properties).to eq({})
      end

      it 'defaults dns to nil' do
        network = Bosh::Director::DeploymentPlan::DynamicNetwork.parse(
          {
            'name' => 'foo',
            'cloud_properties' => {
              'foz' => 'baz'
            }
          },
          [],
          logger
        )
        expect(network.subnets.length).to eq(1)
        expect(network.subnets.first.dns).to eq(nil)
      end

      it 'defaults availability zone to nil' do
        network = Bosh::Director::DeploymentPlan::DynamicNetwork.parse(
          {
            'name' => 'foo',
            'cloud_properties' => {
              'foz' => 'baz'
            }
          },
          [],
          logger)
        expect(network.subnets.first.availability_zone_names).to eq(nil)
      end

      it 'raises error when cloud_properties is NOT a hash' do
        expect {
          Bosh::Director::DeploymentPlan::DynamicNetwork.parse(
              {
                  'name' => 'foo',
                  'cloud_properties' => 'not_hash',
              },
              [],
              logger
          )
        }.to raise_error(Bosh::Director::ValidationInvalidType)
      end

      it "raises error when 'az' is present on the network spec" do
        expect {
          Bosh::Director::DeploymentPlan::DynamicNetwork.parse(
            {
              'name' => 'foo',
              'az' => 'foo-zone'
            },
            [Bosh::Director::DeploymentPlan::AvailabilityZone.new('foo-zone', {})],
            logger
          )
        }.to raise_error(Bosh::Director::NetworkInvalidProperty, "Network 'foo' must not specify 'az'.")
      end

      it "raises error when 'azs' is present on the network spec" do
        expect {
          Bosh::Director::DeploymentPlan::DynamicNetwork.parse(
            {
              'name' => 'foo',
              'azs' => ['foo-zone']
            },
            [Bosh::Director::DeploymentPlan::AvailabilityZone.new('foo-zone', {})],
            logger
          )
        }.to raise_error(Bosh::Director::NetworkInvalidProperty, "Network 'foo' must not specify 'azs'.")
      end
    end

    context 'with a manifest specifying subnets' do
      it 'should parse spec' do
        network = Bosh::Director::DeploymentPlan::DynamicNetwork.parse(
          {
            'name' => 'foo',
            'subnets' => [
              {
                'dns' => %w[1.2.3.4 5.6.7.8],
                'cloud_properties' => {
                  'foz' => 'baz'
                },
                'az' => 'foz-zone'
              },
              {
                'dns' => %w[9.8.7.6 5.4.3.2],
                'cloud_properties' => {
                  'bar' => 'bat'
                },
                'az' => 'foo-zone'
              },
            ]
          },
          [
            Bosh::Director::DeploymentPlan::AvailabilityZone.new('foo-zone', {}),
            Bosh::Director::DeploymentPlan::AvailabilityZone.new('foz-zone', {}),
          ],
          logger
        )

        expect(network.name).to eq('foo')
        expect(network.subnets.length).to eq(2)
        expect(network.subnets.first.dns).to eq(['1.2.3.4', '5.6.7.8'])
        expect(network.subnets.first.cloud_properties).to eq({'foz' => 'baz'})
        expect(network.subnets.first.availability_zone_names).to eq(['foz-zone'])
        expect(network.subnets.last.dns).to eq(['9.8.7.6', '5.4.3.2'])
        expect(network.subnets.last.cloud_properties).to eq({'bar' => 'bat'})
        expect(network.subnets.last.availability_zone_names).to eq(['foo-zone'])
      end

      it 'defaults cloud properties to empty hash' do
        network = Bosh::Director::DeploymentPlan::DynamicNetwork.parse(
          {
            'name' => 'foo',
            'subnets' => [
              {
                'dns' => %w[1.2.3.4 5.6.7.8],
              }
            ]
          },
          [],
          logger
        )

        expect(network.subnets.length).to eq(1)
        expect(network.subnets.first.cloud_properties).to eq({})
      end

      it 'defaults dns to nil' do
        network = Bosh::Director::DeploymentPlan::DynamicNetwork.parse(
          {
            'name' => 'foo',
            'subnets' => [
              {
                'cloud_properties' => {
                  'foz' => 'baz'
                }
              },
            ]
          },
          [],
          logger
        )

        expect(network.subnets.length).to eq(1)
        expect(network.subnets.first.dns).to eq(nil)
      end

      it 'defaults availability zone to nil when not specified' do
        network = Bosh::Director::DeploymentPlan::DynamicNetwork.parse(
          {
            'name' => 'foo',
            'subnets' => [
              {
                'cloud_properties' => {
                  'foz' => 'baz'
                }
              },
            ]
          },
          [],
          logger
        )

        expect(network.subnets.first.availability_zone_names).to eq(nil)
      end

      it 'does not allow availability zone to be nil' do
        expect {
          Bosh::Director::DeploymentPlan::DynamicNetwork.parse(
            {
              'name' => 'foo',
              'subnets' => [
                {
                  'cloud_properties' => {
                    'foz' => 'baz'
                  },
                  'az' => nil
                },
              ]
            },
            [], logger
          )
        }.to raise_error(Bosh::Director::ValidationInvalidType)
      end

      it 'raises error when cloud_properties is NOT a hash' do
        expect {
          Bosh::Director::DeploymentPlan::DynamicNetwork.parse(
              {
                  'name' => 'foo',
                  'subnets' => [
                      {
                          'dns' => %w[1.2.3.4 5.6.7.8],
                          'cloud_properties' => 'not_hash',
                          'az' => 'foz-zone'
                      },
                  ]
              },
              [
                  Bosh::Director::DeploymentPlan::AvailabilityZone.new('foz-zone', {}),
              ],
              logger
          )
        }.to raise_error(Bosh::Director::ValidationInvalidType)
      end

      it 'raises error when dns is present at the top level' do
        expect {
          Bosh::Director::DeploymentPlan::DynamicNetwork.parse(
            {
              'name' => 'foo',
              'dns' => %w[1.2.3.4 5.6.7.8],
              'subnets' => [
                {
                  'dns' => %w[9.8.7.6 5.4.3.2],
                  'cloud_properties' => {
                    'foz' => 'baz'
                  }
                },
              ]
            },
            [],
            logger
          )
        }.to raise_error(Bosh::Director::NetworkInvalidProperty,
            "Network 'foo' must not specify 'dns' when also specifying 'subnets'. " +
              "Instead, 'dns' should be specified on subnet entries.")
      end

      it 'raises error when cloud_properties is present at the top level' do
        expect {
          Bosh::Director::DeploymentPlan::DynamicNetwork.parse({
              'name' => 'foo',
              'cloud_properties' => {
                'foz' => 'baz'
              },
              'subnets' => [
                {
                  'cloud_properties' => {
                    'foz' => 'baz',
                  }
                },
              ]
            },
            [],
            logger
          )
        }.to raise_error(Bosh::Director::NetworkInvalidProperty,
            "Network 'foo' must not specify 'cloud_properties' when also specifying 'subnets'. " +
              "Instead, 'cloud_properties' should be specified on subnet entries.")
      end

      it 'validates the az references an existing AZ' do
        expect {
          Bosh::Director::DeploymentPlan::DynamicNetwork.parse(
            {
              'name' => 'foo',
              'subnets' => [
                'dns' => %w[1.2.3.4 5.6.7.8],
                'cloud_properties' => {
                  'foz' => 'baz'
                },
                'az' => 'foo-zone',
              ],
            },
            [Bosh::Director::DeploymentPlan::AvailabilityZone.new('bar-zone', {})],
            logger
          )
        }.to raise_error(Bosh::Director::NetworkSubnetUnknownAvailabilityZone)
      end
    end
  end

  describe :network_settings do
    before(:each) do
      @network = Bosh::Director::DeploymentPlan::DynamicNetwork.parse({
          'name' => 'foo',
          'cloud_properties' => {
            'foz' => 'baz'
          },
        }, subnets, logger)
    end
    let(:subnets) { [] }

    it 'should provide dynamic network settings' do
      reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, @network)
      reservation.resolve_ip(4294967295)
      expect(@network.network_settings(reservation,[])).to eq({
            'type' => 'dynamic',
            'cloud_properties' => {'foz' => 'baz'},
            'default' => []
          })
    end

    it 'should set the defaults' do
      reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, @network)
      reservation.resolve_ip(4294967295)
      expect(@network.network_settings(reservation)).to eq({
            'type' => 'dynamic',
            'cloud_properties' => {'foz' => 'baz'},
            'default' => ['dns', 'gateway']
          })
    end

    it 'should fail when for static reservation' do
      reservation = Bosh::Director::DesiredNetworkReservation.new_static(instance_model, @network, 1)
      expect {
        @network.network_settings(reservation)
      }.to raise_error Bosh::Director::NetworkReservationWrongType
    end

    context 'when availability zone(s) is specified' do

      let(:azs) { [az1, az2] }
      let(:az1) { Bosh::Director::DeploymentPlan::AvailabilityZone.new('fake-az', {'az_key' => 'az_value'}) }
      let(:az2) { Bosh::Director::DeploymentPlan::AvailabilityZone.new('fake-az2', {'az_key' => 'az_value2'}) }

      context 'when both azs and az are both specified' do
        let(:network) do
          Bosh::Director::DeploymentPlan::DynamicNetwork.parse({
              'name' => 'foo',
              'subnets' => [{
                  'az' => 'fake-az',
                  'azs' => ['fake-az', 'fake-az2'],
                  'cloud_properties' => {'subnet_key' => 'subnet_value'}
                }]
            }, azs, logger)
        end

        it 'errors' do
          expect { network }.to raise_error  Bosh::Director::NetworkInvalidProperty, "Network 'foo' contains both 'az' and 'azs'. Choose one."
        end
      end

      context 'when multiple azs are specified on the network' do
        let(:network) do
          Bosh::Director::DeploymentPlan::DynamicNetwork.parse({
              'name' => 'foo',
              'subnets' => [{
                  'azs' => ['fake-az', 'fake-az2'],
                  'cloud_properties' => {'subnet_key' => 'subnet_value'}
                }]
            }, azs, logger)
        end

        it 'returns settings from the subnet for both azs' do
          reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network)

          expect(network.network_settings(reservation, [], az1)).to eq({
                'type' => 'dynamic',
                'cloud_properties' => {'subnet_key' => 'subnet_value'},
                'default' => []
              })

          expect(network.network_settings(reservation, [], az2)).to eq({
                'type' => 'dynamic',
                'cloud_properties' => {'subnet_key' => 'subnet_value'},
                'default' => []
              })
        end

        it 'raises an error when an empty azs array is specified' do
          expect {
            network = Bosh::Director::DeploymentPlan::DynamicNetwork.parse({
                'name' => 'foo',
                'subnets' => [{
                    'azs' => [],
                    'cloud_properties' => {'subnet_key' => 'subnet_value'}
                  }]
              }, azs, logger)
          }.to raise_error Bosh::Director::NetworkInvalidProperty, "Network 'foo' refers to an empty 'azs' array"
        end

        it 'raises an error when an unknown az is specified' do
          expect {
            network = Bosh::Director::DeploymentPlan::DynamicNetwork.parse({
                'name' => 'foo',
                'subnets' => [{
                    'azs' => ['fake-az', 'say-what'],
                    'cloud_properties' => {'subnet_key' => 'subnet_value'}
                  }]
              }, azs, logger)
          }.to raise_error Bosh::Director::NetworkSubnetUnknownAvailabilityZone, "Network 'foo' refers to an unknown availability zone 'say-what'"
        end

        it 'returns first subnet if instance does not have availability zone' do
          reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network)

          expect(network.network_settings(reservation, [])).to eq({
                'type' => 'dynamic',
                'cloud_properties' => {'subnet_key' => 'subnet_value'},
                'default' => []
              })
        end
      end

      context 'when singular az is specified' do
        let(:network) do
          Bosh::Director::DeploymentPlan::DynamicNetwork.parse({
              'name' => 'foo',
              'subnets' => [{
                  'az' => 'fake-az',
                  'cloud_properties' => {'subnet_key' => 'subnet_value'}
                },
                {
                  'az' => 'fake-az2',
                  'cloud_properties' => {'subnet_key' => 'subnet_value2'}
                }]
            }, azs, logger)
        end

        it 'returns settings from subnet that belongs to specified availability zone' do

          reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network)

          expect(network.network_settings(reservation, [], az2)).to eq({
                'type' => 'dynamic',
                'cloud_properties' => {'subnet_key' => 'subnet_value2'},
                'default' => []
              })
        end

        it 'returns first subnet if instance does not have availability zone' do
          reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network)

          expect(network.network_settings(reservation, [])).to eq({
                'type' => 'dynamic',
                'cloud_properties' => {'subnet_key' => 'subnet_value'},
                'default' => []
              })
        end

        it 'raises an error when there is no subnet in requested az' do
          network =
            Bosh::Director::DeploymentPlan::DynamicNetwork.parse({
                'name' => 'foo',
                'subnets' => [{
                    'az' => 'fake-az',
                    'cloud_properties' => {'subnet_key' => 'subnet_value'}
                  },
                  {
                    'az' => 'fake-az',
                    'cloud_properties' => {'subnet_key' => 'subnet_value2'}
                  }]
              }, azs, logger)

          reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network)

          unknown_az = Bosh::Director::DeploymentPlan::AvailabilityZone.new('fake-unknown-az', {})
          expect {
            network.network_settings(reservation, [], unknown_az)
          }.to raise_error Bosh::Director::NetworkSubnetInvalidAvailabilityZone, "Network 'foo' has no matching subnet for availability zone 'fake-unknown-az'"
        end
      end
    end
  end

  describe 'validate_has_job' do
    let(:network_spec) do
      Bosh::Spec::Deployments.network.merge(
        'type' => 'dynamic',
        'subnets' => [
          {
            'az' => 'zone_1',
          },
          {
            'az' => 'zone_2',
          },
        ],
      )
    end

    let(:network) do
      Bosh::Director::DeploymentPlan::DynamicNetwork.parse(
        network_spec,
        [
          Bosh::Director::DeploymentPlan::AvailabilityZone.new('zone_1', {}),
          Bosh::Director::DeploymentPlan::AvailabilityZone.new('zone_2', {}),
        ],
        logger
      )
    end

    it 'passes when all availability zone names are contained by subnets' do
      expect(network.has_azs?([])).to eq(true)
      expect(network.has_azs?(['zone_1'])).to eq(true)
      expect(network.has_azs?(['zone_2'])).to eq(true)
      expect(network.has_azs?(['zone_1', 'zone_2'])).to eq(true)
    end

    it 'raises when any availability zone are not contained by a subnet' do
      expect(network.has_azs?(['zone_1', 'zone_3', 'zone_2', 'zone_4'])).to eq(false)
    end

    it 'raises when job does not have az, but subnets do' do
      expect(network.has_azs?(nil)).to eq(false)
    end
  end

  describe :validate_reference_from_job do
    it 'returns true if job has a valid network spec' do
      dynamic_network = Bosh::Director::DeploymentPlan::DynamicNetwork.new('dynamic', [], logger)
      job_network_spec = {'name' => 'dynamic'}

      expect {
        dynamic_network.validate_reference_from_job!(job_network_spec, 'job-name')
      }.to_not raise_error
    end

    context 'when network is dynamic but job network spec uses static ips' do
      it 'raises StaticIPNotSupportedOnDynamicNetwork' do
        dynamic_network = Bosh::Director::DeploymentPlan::DynamicNetwork.new('dynamic', [], logger)
        job_network_spec = {
          'name' => 'dynamic',
          'static_ips' => ['192.168.1.10']
        }

        expect {
          dynamic_network.validate_reference_from_job!(job_network_spec, 'job-name')
        }.to raise_error Bosh::Director::JobStaticIPNotSupportedOnDynamicNetwork, "Instance group 'job-name' using dynamic network 'dynamic' cannot specify static IP(s)"
      end
    end
  end
end
