require 'spec_helper'

describe Bosh::Director::DeploymentPlan::DynamicNetwork do
  before(:each) do
    @deployment_plan = instance_double('Bosh::Director::DeploymentPlan::Planner')
  end

  let(:logger) { Logging::Logger.new('TestLogger') }
  let(:instance) { instance_double(Bosh::Director::DeploymentPlan::Instance) }

  describe '.parse' do
    context 'with a manifest using the old format without explicit subnets' do
      it 'parses the spec and creates a subnet from the dns and cloud properties' do
        network = BD::DeploymentPlan::DynamicNetwork.parse(
          {
            'name' => 'foo',
            'dns' => %w[1.2.3.4 5.6.7.8],
            'cloud_properties' => {
              'foz' => 'baz'
            },
            'availability_zone' => 'foo-zone'
          },
          [BD::DeploymentPlan::AvailabilityZone.new('foo-zone', {})],
          logger
        )

        expect(network.name).to eq('foo')
        expect(network.subnets.length).to eq(1)
        expect(network.subnets.first.dns).to eq(['1.2.3.4', '5.6.7.8'])
        expect(network.subnets.first.cloud_properties).to eq({'foz' => 'baz'})
        expect(network.subnets.first.availability_zone_name).to eq('foo-zone')
      end

      it 'defaults cloud properties to empty hash' do
        network = BD::DeploymentPlan::DynamicNetwork.parse(
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
        network = BD::DeploymentPlan::DynamicNetwork.parse(
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
        network = BD::DeploymentPlan::DynamicNetwork.parse(
          {
            'name' => 'foo',
            'cloud_properties' => {
              'foz' => 'baz'
            }
          },
          [],
          logger)
        expect(network.subnets.first.availability_zone_name).to eq(nil)
      end

      it 'does not allow availability zone to be nil' do
        expect {
          BD::DeploymentPlan::DynamicNetwork.parse(
            {
              'name' => 'foo',
              'cloud_properties' => {
                'foz' => 'baz'
              },
              'availability_zone' => nil
            },
            [],
            logger
          )
        }.to raise_error(BD::ValidationInvalidType)
      end

      it 'validates the availability_zone references an existing AZ' do
        expect {
          BD::DeploymentPlan::DynamicNetwork.parse(
            {
              'name' => 'foo',
              'dns' => %w[1.2.3.4 5.6.7.8],
              'cloud_properties' => {
                'foz' => 'baz'
              },
              'availability_zone' => 'foo-zone'
            },
            [BD::DeploymentPlan::AvailabilityZone.new('bar-zone', {})],
            logger
          )
        }.to raise_error(BD::NetworkSubnetUnknownAvailabilityZone)
      end
    end

    context 'with a manifest specifying subnets' do
      it 'should parse spec' do
        network = BD::DeploymentPlan::DynamicNetwork.parse(
          {
            'name' => 'foo',
            'subnets' => [
              {
                'dns' => %w[1.2.3.4 5.6.7.8],
                'cloud_properties' => {
                  'foz' => 'baz'
                },
                'availability_zone' => 'foz-zone'
              },
              {
                'dns' => %w[9.8.7.6 5.4.3.2],
                'cloud_properties' => {
                  'bar' => 'bat'
                },
                'availability_zone' => 'foo-zone'
              },
            ]
          },
          [
            BD::DeploymentPlan::AvailabilityZone.new('foo-zone', {}),
            BD::DeploymentPlan::AvailabilityZone.new('foz-zone', {}),
          ],
          logger
        )

        expect(network.name).to eq('foo')
        expect(network.subnets.length).to eq(2)
        expect(network.subnets.first.dns).to eq(['1.2.3.4', '5.6.7.8'])
        expect(network.subnets.first.cloud_properties).to eq({'foz' => 'baz'})
        expect(network.subnets.first.availability_zone_name).to eq('foz-zone')
        expect(network.subnets.last.dns).to eq(['9.8.7.6', '5.4.3.2'])
        expect(network.subnets.last.cloud_properties).to eq({'bar' => 'bat'})
        expect(network.subnets.last.availability_zone_name).to eq('foo-zone')
      end

      it 'defaults cloud properties to empty hash' do
        network = BD::DeploymentPlan::DynamicNetwork.parse(
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
        network = BD::DeploymentPlan::DynamicNetwork.parse(
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
        network = BD::DeploymentPlan::DynamicNetwork.parse(
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

        expect(network.subnets.first.availability_zone_name).to eq(nil)
      end

      it 'does not allow availability zone to be nil' do
        expect {
          BD::DeploymentPlan::DynamicNetwork.parse(
            {
              'name' => 'foo',
              'subnets' => [
                {
                  'cloud_properties' => {
                    'foz' => 'baz'
                  },
                  'availability_zone' => nil
                },
              ]
            },
            [], logger
          )
        }.to raise_error(BD::ValidationInvalidType)
      end

      it 'raises error when dns is present at the top level' do
        expect {
          BD::DeploymentPlan::DynamicNetwork.parse(
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
        }.to raise_error(BD::NetworkInvalidProperty, "top-level 'dns' invalid when specifying subnets")
      end

      it 'raises error when availability zone is present at the top level' do
        expect {
          BD::DeploymentPlan::DynamicNetwork.parse(
            {
              'name' => 'foo',
              'availability_zone' => 'foo-zone',
              'subnets' => [
                {
                  'dns' => %w[9.8.7.6 5.4.3.2],
                  'cloud_properties' => {
                    'foz' => 'baz'
                  }
                },
              ]
            },
            [BD::DeploymentPlan::AvailabilityZone.new('foo-zone', {})],
            logger
          )
        }.to raise_error(BD::NetworkInvalidProperty, "top-level 'availability_zone' invalid when specifying subnets")
      end

      it 'raises error when cloud_properties is present at the top level' do
        expect {
          BD::DeploymentPlan::DynamicNetwork.parse({
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
        }.to raise_error(BD::NetworkInvalidProperty, "top-level 'cloud_properties' invalid when specifying subnets")

      end

      it 'validates the availability_zone references an existing AZ' do
        expect {
          BD::DeploymentPlan::DynamicNetwork.parse(
            {
              'name' => 'foo',
              'subnets' => [
                'dns' => %w[1.2.3.4 5.6.7.8],
                'cloud_properties' => {
                  'foz' => 'baz'
                },
                'availability_zone' => 'foo-zone',
              ],
            },
            [BD::DeploymentPlan::AvailabilityZone.new('bar-zone', {})],
            logger
          )
        }.to raise_error(BD::NetworkSubnetUnknownAvailabilityZone)
      end
    end
  end

  describe :network_settings do
    before(:each) do
      @network = BD::DeploymentPlan::DynamicNetwork.parse({
          'name' => 'foo',
          'cloud_properties' => {
            'foz' => 'baz'
          },
        }, subnets, logger)
    end
    let(:subnets) { [] }

    it 'should provide dynamic network settings' do
      reservation = BD::DynamicNetworkReservation.new(instance, @network)
      reservation.resolve_ip(4294967295)
      expect(@network.network_settings(reservation,[])).to eq({
            'type' => 'dynamic',
            'cloud_properties' => {'foz' => 'baz'},
            'default' => []
          })
    end

    it 'should set the defaults' do
      reservation = BD::DynamicNetworkReservation.new(instance, @network)
      reservation.resolve_ip(4294967295)
      expect(@network.network_settings(reservation)).to eq({
            'type' => 'dynamic',
            'cloud_properties' => {'foz' => 'baz'},
            'default' => ['dns', 'gateway']
          })
    end

    it 'should fail when for static reservation' do
      reservation = BD::StaticNetworkReservation.new(instance, @network, 1)
      expect {
        @network.network_settings(reservation)
      }.to raise_error BD::NetworkReservationWrongType
    end

    context 'when availability zone is specified' do
      let(:azs) { [az1, az2] }
      let(:az1) { BD::DeploymentPlan::AvailabilityZone.new('fake-az', {'az_key' => 'az_value'}) }
      let(:az2) { BD::DeploymentPlan::AvailabilityZone.new('fake-az2', {'az_key' => 'az_value2'}) }

      let (:network) do
        BD::DeploymentPlan::DynamicNetwork.parse({
            'name' => 'foo',
            'subnets' => [{
              'availability_zone' => 'fake-az',
              'cloud_properties' => {'subnet_key' => 'subnet_value'}
            },
            {
              'availability_zone' => 'fake-az2',
              'cloud_properties' => {'subnet_key' => 'subnet_value2'}
            }]
          }, azs, logger)
      end

      it 'returns settings from subnet that belongs to specified availability zone' do

        reservation = BD::DynamicNetworkReservation.new(instance, network)

        expect(network.network_settings(reservation, [], az2)).to eq({
          'type' => 'dynamic',
          'cloud_properties' => { 'subnet_key' => 'subnet_value2'},
          'default' => []
        })
      end

      it 'returns first subnet if instance does not have availability zone' do
        reservation = BD::DynamicNetworkReservation.new(instance, network)

        expect(network.network_settings(reservation, [])).to eq({
          'type' => 'dynamic',
          'cloud_properties' => { 'subnet_key' => 'subnet_value'},
          'default' => []
        })
      end

      it 'raises an error when there is no subnet in requested az' do
        network =
          BD::DeploymentPlan::DynamicNetwork.parse({
              'name' => 'foo',
              'subnets' => [{
                  'availability_zone' => 'fake-az',
                  'cloud_properties' => {'subnet_key' => 'subnet_value'}
                },
                {
                  'availability_zone' => 'fake-az',
                  'cloud_properties' => {'subnet_key' => 'subnet_value2'}
                }]
            }, azs, logger)

        reservation = BD::DynamicNetworkReservation.new(instance, network)

        unknown_az = BD::DeploymentPlan::AvailabilityZone.new('fake-unknown-az', {})
        expect {
          network.network_settings(reservation, [], unknown_az)
        }.to raise_error BD::NetworkSubnetInvalidAvailabilityZone, "Network 'foo' has no matching subnet for availability zone 'fake-unknown-az'"
      end
    end
  end

  describe 'validate_has_job' do
    let(:network_spec) do
      Bosh::Spec::Deployments.network.merge(
        'type' => 'dynamic',
        'subnets' => [
          {
            'availability_zone' => 'zone_1',
          },
          {
            'availability_zone' => 'zone_2'
          },
        ]
      )
    end

    let(:network) do
      BD::DeploymentPlan::DynamicNetwork.parse(
        network_spec,
        [
          BD::DeploymentPlan::AvailabilityZone.new('zone_1', {}),
          BD::DeploymentPlan::AvailabilityZone.new('zone_2', {}),
        ],
        logger
      )
    end

    it 'passes when all availability zone names are contained by subnets' do
      expect { network.validate_has_job!([], 'foo-job') }.to_not raise_error
      expect { network.validate_has_job!(['zone_1'], 'foo-job') }.to_not raise_error
      expect { network.validate_has_job!(['zone_2'], 'foo-job') }.to_not raise_error
      expect { network.validate_has_job!(['zone_1', 'zone_2'], 'foo-job') }.to_not raise_error
    end

    it 'raises when any availability zone are not contained by a subnet' do
      expect {
        network.validate_has_job!(['zone_1', 'zone_3', 'zone_2', 'zone_4'], 'foo-job')
      }.to raise_error(
          Bosh::Director::JobNetworkMissingRequiredAvailabilityZone,
          "Job 'foo-job' refers to an availability zone(s) '[\"zone_3\", \"zone_4\"]' but 'a' has no matching subnet(s)."
        )
    end
  end
end
