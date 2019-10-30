require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe PlacementPlanner::StaticIpsAvailabilityZonePicker do
    include Bosh::Director::IpUtil

    subject(:zone_picker) do
      PlacementPlanner::StaticIpsAvailabilityZonePicker.new(
        instance_plan_factory,
        network_planner,
        instance_group.networks,
        'fake-instance-group',
        availability_zones,
        logger,
      )
    end

    let(:availability_zones) { instance_group.availability_zones }
    let(:cloud_configs) { [Bosh::Director::Models::Config.make(:cloud, content: YAML.dump(cloud_config_hash))] }
    let!(:deployment_model) { Bosh::Director::Models::Deployment.make(manifest: YAML.dump(manifest_hash), name: manifest_hash['name']) }
    let(:deployment_repo) { DeploymentRepo.new }
    let(:desired_instances) { [].tap { |a| desired_instance_count.times { a << new_desired_instance } } }
    let(:desired_instance_count) { 3 }
    let(:event_log) { Bosh::Director::EventLog::Log.new(StringIO.new('')) }
    let(:index_assigner) { PlacementPlanner::IndexAssigner.new(deployment_model) }
    let(:instance_repo) { Bosh::Director::DeploymentPlan::InstanceRepository.new(logger, variables_interpolator) }
    let(:instance_plans) { zone_picker.place_and_match_in(desired_instances, existing_instances) }

    let(:instance_plan_factory) do
      InstancePlanFactory.new(
        instance_repo,
        {},
        planner,
        index_assigner,
        variables_interpolator,
        [],
      )
    end

    let(:network_planner) { NetworkPlanner::Planner.new(logger) }
    let(:planner) do
      planner = planner_factory.create_from_manifest(manifest, cloud_configs, [], {})
      stemcell = Stemcell.parse(manifest_hash['stemcells'].first)
      planner.add_stemcell(stemcell)
      planner
    end
    let(:planner_factory) { PlannerFactory.new(manifest_validator, deployment_repo, logger) }
    let(:manifest_validator) { Bosh::Director::DeploymentPlan::ManifestValidator.new(logger) }
    let(:manifest) { Bosh::Director::Manifest.new(manifest_hash, YAML.dump(manifest_hash), cloud_config_hash, nil) }
    let(:instance_group) { planner.instance_groups.first }
    let(:instance_group_availability_zones) { %w[zone1 zone2] }
    let(:instance_group_networks) { [{ 'name' => 'a', 'static_ips' => static_ips }] }

    let(:new_instance_plans) { instance_plans.select(&:new?) }
    let(:existing_instance_plans) { instance_plans.reject(&:new?).reject(&:obsolete?) }
    let(:obsolete_instance_plans) { instance_plans.select(&:obsolete?) }
    let(:variables_interpolator) { instance_double(Bosh::Director::ConfigServer::VariablesInterpolator) }

    def make_subnet_spec(range, static_ips, zone_names)
      spec = {
        'range' => range,
        'gateway' => NetAddr::CIDR.create(range)[1].ip,
        'dns' => ['8.8.8.8'],
        'static' => static_ips,
        'reserved' => [],
        'cloud_properties' => {},
      }
      spec['azs'] = zone_names if zone_names
      spec
    end
    let(:networks_spec) do
      [
        { 'name' => 'a',
          'subnets' => [
            make_subnet_spec('192.168.1.0/24', ['192.168.1.10 - 192.168.1.14'], ['zone1']),
            make_subnet_spec('192.168.2.0/24', ['192.168.2.10 - 192.168.2.14'], ['zone2']),
          ] },
        { 'name' => 'b',
          'subnets' => [
            make_subnet_spec('10.10.1.0/24', ['10.10.1.10 - 10.10.1.14'], ['zone1']),
            make_subnet_spec('10.10.2.0/24', ['10.10.2.10 - 10.10.2.14'], ['zone2']),
          ] },
      ]
    end

    let(:cloud_config_hash) do
      {
        'networks' => networks_spec,
        'compilation' => { 'workers' => 1, 'network' => 'a', 'cloud_properties' => {}, 'az' => cloud_config_availability_zones.first['name'] },
        'vm_types' => [{
          'name' => 'tiny',
        }],
        'azs' => cloud_config_availability_zones,
      }
    end
    let(:cloud_config_availability_zones) do
      [
        { 'name' => 'zone1', 'cloud_properties' => { foo: 'bar' } },
        { 'name' => 'zone2', 'cloud_properties' => { foo: 'baz' } },
      ]
    end
    let(:manifest_hash) do
      {
        'name' => 'simple',
        'releases' => [{ 'name' => 'bosh-release', 'version' => '0.1-dev' }],
        'update' => { 'canaries' => 2, 'canary_watch_time' => 4000, 'max_in_flight' => 1, 'update_watch_time' => 20 },
        'stemcells' => [{ 'name' => 'ubuntu-stemcell', 'version' => '1', 'alias' => 'default' }],
        'instance_groups' => [
          {
            'name' => 'fake-instance-group',
            'jobs' => [{ 'name' => 'foobar', 'release' => 'bosh-release' }],
            'vm_type' => 'tiny',
            'stemcell' => 'default',
            'instances' => desired_instance_count,
            'networks' => instance_group_networks,
            'azs' => instance_group_availability_zones,
          },
        ],
      }
    end

    before do
      fake_job

      Bosh::Director::Models::VariableSet.make(deployment: deployment_model)
      release = Bosh::Director::Models::Release.make(name: 'bosh-release')
      template = Bosh::Director::Models::Template.make(name: 'foobar', release: release)
      release_version = Bosh::Director::Models::ReleaseVersion.make(version: '0.1-dev', release: release)
      release_version.add_template(template)
    end

    describe '#place_and_match_in' do
      context 'with no existing instances' do
        let(:existing_instances) { [] }
        let(:static_ips) { ['192.168.1.10 - 192.168.1.12'] }

        context 'when the subnets and the instance_groups do not specify availability zones' do
          let(:networks_spec) do
            [
              { 'name' => 'a',
                'subnets' => [
                  make_subnet_spec('192.168.1.0/24', ['192.168.1.10 - 192.168.1.14'], nil),
                  make_subnet_spec('192.168.2.0/24', ['192.168.2.10 - 192.168.2.14'], nil),
                ] },
              { 'name' => 'b',
                'subnets' => [
                  make_subnet_spec('10.10.1.0/24', ['10.10.1.10 - 10.10.1.14'], nil),
                  make_subnet_spec('10.10.2.0/24', ['10.10.2.10 - 10.10.2.14'], nil),
                ] },
            ]
          end
          before do
            manifest_hash['instance_groups'].each { |entry| entry.delete('azs') }
            cloud_config_hash['compilation'].delete('az')
          end

          it 'does not assign AZs' do
            expect(instance_plans.map(&:desired_instance).map(&:az)).to eq([nil, nil, nil])
          end
        end

        context 'when the instance group specifies a single network with all static IPs from a single AZ' do
          it 'assigns instances to the AZ' do
            expect(new_instance_plans.size).to eq(3)
            expect(existing_instance_plans).to eq([])
            expect(obsolete_instance_plans).to eq([])
            expect(new_instance_plans.map(&:desired_instance).map(&:az).map(&:name)).to eq(%w[zone1 zone1 zone1])
            expect(new_instance_plans.map(&:network_plans).flatten.map(&:reservation).map(&:ip)).to eq(
              [ip_to_i('192.168.1.10'), ip_to_i('192.168.1.11'), ip_to_i('192.168.1.12')],
            )
          end
        end

        context 'when an instance group specifies a static ip that belongs to no subnet' do
          let(:static_ips) { ['192.168.3.5'] }
          let(:desired_instance_count) { 1 }

          it 'raises an exception' do
            expect { instance_plans }.to raise_error(
              Bosh::Director::InstanceGroupNetworkInstanceIpMismatch,
              "Instance group 'fake-instance-group' with network 'a' " \
              "declares static ip '192.168.3.5', which belongs to no subnet",
            )
          end
        end

        context 'when the instance group specifies a single network with static IPs from different AZs' do
          let(:static_ips) { ['192.168.1.10', '192.168.1.11', '192.168.2.10'] }

          it 'assigns instances to the AZs' do
            expect(new_instance_plans.size).to eq(3)
            expect(existing_instance_plans).to eq([])
            expect(obsolete_instance_plans).to eq([])

            expect(new_instance_plans[0].desired_instance.az.name).to eq('zone1')
            expect(new_instance_plans[1].desired_instance.az.name).to eq('zone1')
            expect(new_instance_plans[2].desired_instance.az.name).to eq('zone2')
          end
        end

        context 'when instance group specifies a single network with static IP spanning multiple AZs' do
          let(:instance_group_availability_zones) { ['zone1'] }
          let(:networks_spec) do
            [
              { 'name' => 'a',
                'subnets' => [
                  make_subnet_spec('192.168.1.0/24',
                                   ['192.168.1.10 - 192.168.1.14'],
                                   %w[zone1 zone2]),
                ] },
            ]
          end

          let(:static_ips) { ['192.168.1.10', '192.168.1.11', '192.168.1.12'] }

          it 'picks az that is specified on a instance group and static IP belongs to' do
            expect(new_instance_plans.size).to eq(3)
            expect(existing_instance_plans).to eq([])
            expect(obsolete_instance_plans).to eq([])

            expect(new_instance_plans[0].desired_instance.az.name).to eq('zone1')
            expect(new_instance_plans[1].desired_instance.az.name).to eq('zone1')
            expect(new_instance_plans[2].desired_instance.az.name).to eq('zone1')
          end
        end

        context 'when the instance group specifies multiple networks with static IPs from the same AZ' do
          let(:desired_instance_count) { 2 }
          let(:instance_group_networks) do
            [
              { 'name' => 'a', 'static_ips' => ['192.168.1.10', '192.168.1.11'], 'default' => %w[dns gateway] },
              { 'name' => 'b', 'static_ips' => ['10.10.1.10', '10.10.1.11'] },
            ]
          end

          it 'assigns instances to the AZ' do
            expect(new_instance_plans.size).to eq(2)
            expect(existing_instance_plans).to eq([])
            expect(obsolete_instance_plans).to eq([])

            expect(new_instance_plans[0].desired_instance.az.name).to eq('zone1')
            expect(new_instance_plans[0].network_plans.map(&:reservation).map(&:ip)).to eq(
              [ip_to_i('192.168.1.10'), ip_to_i('10.10.1.10')],
            )

            expect(new_instance_plans[1].desired_instance.az.name).to eq('zone1')
            expect(new_instance_plans[1].network_plans.map(&:reservation).map(&:ip)).to eq(
              [ip_to_i('192.168.1.11'), ip_to_i('10.10.1.11')],
            )
          end
        end

        context 'when the instance group specifies multiple networks with static IPs from different non-overlapping AZs' do
          let(:desired_instance_count) { 2 }
          let(:instance_group_networks) do
            [
              { 'name' => 'a', 'static_ips' => ['192.168.1.10', '192.168.2.10'], 'default' => %w[dns gateway] },
              { 'name' => 'b', 'static_ips' => ['10.10.1.10', '10.10.2.10'] },
            ]
          end

          it 'assigns instances to different AZs' do
            expect(new_instance_plans.size).to eq(2)
            expect(existing_instance_plans).to eq([])
            expect(obsolete_instance_plans).to eq([])

            expect(new_instance_plans[0].desired_instance.az.name).to eq('zone1')
            expect(new_instance_plans[0].network_plans.map(&:reservation).map(&:ip)).to eq(
              [ip_to_i('192.168.1.10'), ip_to_i('10.10.1.10')],
            )

            expect(new_instance_plans[1].desired_instance.az.name).to eq('zone2')
            expect(new_instance_plans[1].network_plans.map(&:reservation).map(&:ip)).to eq(
              [ip_to_i('192.168.2.10'), ip_to_i('10.10.2.10')],
            )
          end
        end

        context 'when instance group specifies multiple networks with static IPs from different overlapping AZs' do
          let(:desired_instance_count) { 4 }
          let(:instance_group_networks) do
            [
              { 'name' => 'a', 'static_ips' => ['192.168.1.10-192.168.1.12', '192.168.2.10'], 'default' => %w[dns gateway] },
              { 'name' => 'b', 'static_ips' => ['10.10.1.10 - 10.10.1.11', '10.10.2.10-10.10.2.11'] },
              { 'name' => 'c', 'static_ips' => ['172.16.1.10', '172.16.2.10-172.16.2.12'] },
              { 'name' => 'd', 'static_ips' => ['64.8.1.10', '64.8.2.10', '64.8.3.10-64.8.3.11'] },
            ]
          end
          let(:instance_group_availability_zones) { %w[z1 z2 z3 z4] }
          let(:networks_spec) do
            [
              { 'name' => 'a',
                'subnets' => [
                  make_subnet_spec('192.168.1.0/24', ['192.168.1.10 - 192.168.1.14'], %w[z1 z2 z3]),
                  make_subnet_spec('192.168.2.0/24', ['192.168.2.10 - 192.168.2.14'], ['z4']),
                ] },
              { 'name' => 'b',
                'subnets' => [
                  make_subnet_spec('10.10.1.0/24', ['10.10.1.10 - 10.10.1.14'], %w[z1 z2]),
                  make_subnet_spec('10.10.2.0/24', ['10.10.2.10 - 10.10.2.14'], %w[z3 z4]),
                ] },
              { 'name' => 'c',
                'subnets' => [
                  make_subnet_spec('172.16.1.0/24', ['172.16.1.10 - 172.16.1.14'], ['z1']),
                  make_subnet_spec('172.16.2.0/24', ['172.16.2.10 - 172.16.2.14'], %w[z2 z3 z4]),
                ] },
              { 'name' => 'd',
                'subnets' => [
                  make_subnet_spec('64.8.1.0/24', ['64.8.1.10 - 64.8.1.14'], ['z1']),
                  make_subnet_spec('64.8.2.0/24', ['64.8.2.10 - 64.8.2.14'], ['z2']),
                  make_subnet_spec('64.8.3.0/24', ['64.8.3.10 - 64.8.3.14'], %w[z3 z4]),
                ] },
            ]
          end
          let(:cloud_config_availability_zones) do
            [{ 'name' => 'z1' }, { 'name' => 'z2' }, { 'name' => 'z3' }, { 'name' => 'z4' }]
          end

          it 'picks AZs for instances to fit all instances' do
            expect(new_instance_plans.size).to eq(4)
            expect(existing_instance_plans).to eq([])
            expect(obsolete_instance_plans).to eq([])

            network_plans = {}
            new_instance_plans.map(&:network_plans).flatten.each do |network_plan|
              network_plans[network_plan.reservation.network.name] ||= []
              network_plans[network_plan.reservation.network.name] << format_ip(network_plan.reservation.ip)
            end

            expect(network_plans['a']).to match_array(['192.168.1.10', '192.168.1.11', '192.168.1.12', '192.168.2.10'])
            expect(network_plans['b']).to match_array(['10.10.1.10', '10.10.1.11', '10.10.2.10', '10.10.2.11'])
            expect(network_plans['c']).to match_array(['172.16.1.10', '172.16.2.12', '172.16.2.10', '172.16.2.11'])
            expect(network_plans['d']).to match_array(['64.8.1.10', '64.8.2.10', '64.8.3.10', '64.8.3.11'])

            expect(new_instance_plans.map(&:desired_instance).map(&:az).map(&:name)).to match_array(%w[z1 z2 z3 z4])
          end
        end

        context 'when instance_group static IP counts for each AZ in networks do not match' do
          let(:desired_instance_count) { 2 }
          let(:instance_group_networks) do
            [
              { 'name' => 'a', 'static_ips' => ['192.168.1.10', '192.168.2.10'], 'default' => %w[dns gateway] },
              { 'name' => 'b', 'static_ips' => ['10.10.1.10', '10.10.1.11'] },
            ]
          end

          it 'raises an error' do
            expect { instance_plans }.to raise_error(
              Bosh::Director::InstanceGroupNetworkInstanceIpMismatch,
              "Failed to evenly distribute static IPs between zones for instance group 'fake-instance-group'",
            )
          end
        end
      end

      context 'when there are existing instances' do
        context 'with one network' do
          context 'when all existing instances match static IPs and AZs' do
            let(:desired_instance_count) { 2 }
            let(:static_ips) { ['192.168.1.10', '192.168.2.10'] }
            let(:existing_instances) do
              [
                existing_instance_with_az_and_ips('zone1', ['192.168.1.10']),
                existing_instance_with_az_and_ips('zone2', ['192.168.2.10']),
              ]
            end

            it 'reuses existing instances' do
              expect(new_instance_plans).to eq([])
              expect(obsolete_instance_plans).to eq([])
              expect(existing_instance_plans.size).to eq(2)
              expect(existing_instance_plans[0].desired_instance.az.name).to eq('zone1')
              expect(existing_instance_plans[0].network_plans.map(&:reservation).map(&:ip)).to eq([ip_to_i('192.168.1.10')])
              expect(existing_instance_plans[1].desired_instance.az.name).to eq('zone2')
              expect(existing_instance_plans[1].network_plans.map(&:reservation).map(&:ip)).to eq([ip_to_i('192.168.2.10')])
            end
          end

          context 'when existing instance static IP was moved to another AZ' do
            let(:desired_instance_count) { 2 }
            let(:static_ips) { ['192.168.1.10', '192.168.2.10'] }
            let(:existing_instances) do
              [
                existing_instance_with_az_and_ips('zone1', ['192.168.1.10']),
                existing_instance_with_az_and_ips('zone2', ['192.168.2.10']),
              ]
            end
            let(:instance_group_availability_zones) { ['zone1'] }

            before do
              cloud_config_hash['networks'].first['subnets'][1]['azs'] = ['zone1']
            end

            it 'raises an error' do
              expect do
                new_instance_plans
              end.to raise_error(
                Bosh::Director::NetworkReservationError,
                "Existing instance 'fake-instance-group/#{existing_instances[1].index}' " \
                "is using IP '192.168.2.10' in availability zone 'zone2'",
              )
            end
          end

          context 'when existing instance static IP is no longer in the list of instance_group static ips' do
            let(:desired_instance_count) { 2 }
            let(:static_ips) { ['192.168.1.14', '192.168.2.14'] }
            let(:existing_instances) do
              [
                existing_instance_with_az_and_ips('zone1', ['192.168.1.10']),
                existing_instance_with_az_and_ips('zone2', ['192.168.2.10']),
              ]
            end
            let(:instance_group_availability_zones) { %w[zone1 zone2] }

            context 'when AZ is the same' do
              it 'picks new IP for instance that is not used by other instances' do
                expect(new_instance_plans).to eq([])
                expect(obsolete_instance_plans).to eq([])
                expect(existing_instance_plans.size).to eq(2)
                expect(existing_instance_plans[0].desired_instance.az.name).to eq('zone1')
                expect(existing_instance_plans[0].network_plans.map(&:reservation).map(&:ip)).to eq([ip_to_i('192.168.1.14')])
                expect(existing_instance_plans[1].desired_instance.az.name).to eq('zone2')
                expect(existing_instance_plans[1].network_plans.map(&:reservation).map(&:ip)).to eq([ip_to_i('192.168.2.14')])
              end

              context 'when the instance that was assigned that ip is in ignore state' do
                let(:desired_instance_count) { 1 }
                let(:static_ips) { ['192.168.1.14'] }

                it 'raises an error' do
                  existing_instances.each do |instance|
                    instance.update(ignore: true)
                  end
                  expect do
                    instance_plans
                  end.to raise_error(
                    Bosh::Director::DeploymentIgnoredInstancesModification,
                    "In instance group 'fake-instance-group', an attempt was made to remove a static ip " \
                    'that is used by an ignored instance. This operation is not allowed.',
                  )
                end
              end
            end

            context 'when static IP and AZ were changed' do
              let(:static_ips) { ['192.168.1.10', '192.168.1.14'] }

              it 'recreates instance in new AZ with new IP' do
                expect(new_instance_plans.size).to eq(1)
                expect(new_instance_plans[0].desired_instance.az.name).to eq('zone1')
                expect(new_instance_plans[0].network_plans.map(&:reservation).map(&:ip)).to eq([ip_to_i('192.168.1.14')])

                expect(obsolete_instance_plans.size).to eq(1)
                expect(obsolete_instance_plans.first.existing_instance).to eq(existing_instances[1])

                expect(existing_instance_plans.size).to eq(1)
                expect(existing_instance_plans[0].desired_instance.az.name).to eq('zone1')
                expect(existing_instance_plans[0].network_plans.map(&:reservation).map(&:ip)).to eq([ip_to_i('192.168.1.10')])
              end

              it 'raises error if removed IP belonged to an ignored instance' do
                existing_instances.each do |instance|
                  instance.update(ignore: true)
                end
                expect do
                  instance_plans
                end.to raise_error(
                  Bosh::Director::DeploymentIgnoredInstancesModification,
                  "In instance group 'fake-instance-group', an attempt was made to remove a static ip " \
                  'that is used by an ignored instance. This operation is not allowed.',
                )
              end
            end
          end

          context 'when subnet specifies several AZs (static IP belongs to several AZs)' do
            let(:desired_instance_count) { 1 }
            let(:networks_spec) do
              [
                { 'name' => 'a',
                  'subnets' => [
                    make_subnet_spec('192.168.1.0/24', ['192.168.1.10 - 192.168.1.14'], new_subnet_azs),
                  ] },
              ]
            end
            let(:new_subnet_azs) { %w[zone2 zone1] }
            let(:static_ips) { ['192.168.1.10'] }
            let(:existing_instances) { [existing_instance_with_az_and_ips('zone1', ['192.168.1.10'])] }

            it 'reuses AZ that existing instance with static IP belongs to' do
              expect(new_instance_plans).to eq([])
              expect(obsolete_instance_plans).to eq([])
              expect(existing_instance_plans.size).to eq(1)
              expect(existing_instance_plans[0].desired_instance.az.name).to eq('zone1')
              expect(existing_instance_plans[0].network_plans.map(&:reservation).map(&:ip)).to eq([ip_to_i('192.168.1.10')])
            end

            context 'when AZ to which instance belongs is removed' do
              let(:new_subnet_azs) { ['zone2'] }
              let(:instance_group_availability_zones) { ['zone2'] }
              before { cloud_config_hash['compilation']['az'] = 'zone2' }

              it 'raises an error' do
                expect do
                  new_instance_plans
                end.to raise_error(
                  Bosh::Director::NetworkReservationError,
                  "Existing instance 'fake-instance-group/#{existing_instances[0].index}' " \
                  "is using IP '192.168.1.10' in availability zone 'zone1'",
                )
              end
            end

            context 'when adding more instances' do
              let(:desired_instance_count) { 4 }
              let(:static_ips) { ['192.168.1.10', '192.168.1.11', '192.168.1.12', '192.168.1.13'] }
              let(:existing_instances) do
                [
                  existing_instance_with_az_and_ips('zone1', ['192.168.1.10']),
                  existing_instance_with_az_and_ips('zone1', ['192.168.1.12']),
                ]
              end
              it 'should distribute the instances across the azs taking into account the existing instances' do
                expect(obsolete_instance_plans).to eq([])

                expect(existing_instance_plans.size).to eq(2)
                expect(existing_instance_plans[0].desired_instance.az.name).to eq('zone1')
                expect(existing_instance_plans[1].desired_instance.az.name).to eq('zone1')

                expect(new_instance_plans.size).to eq(2)
                expect(new_instance_plans[0].desired_instance.az.name).to eq('zone2')
                expect(new_instance_plans[1].desired_instance.az.name).to eq('zone2')
              end
            end
          end

          context 'when a static IP was replaced by another static IP' do
            let(:desired_instance_count) { 2 }
            let(:static_ips) { ['192.168.1.10', '192.168.2.11'] }
            let(:existing_instances) do
              [
                existing_instance_with_az_and_ips('zone1', ['192.168.1.10']),
                existing_instance_with_az_and_ips('zone2', ['192.168.2.10']),
              ]
            end

            it 'will fail if the original static IP was assigned to an ignored VM' do
              existing_instances.each do |instance|
                instance.update(ignore: true)
              end
              expect do
                instance_plans
              end.to raise_error(
                Bosh::Director::DeploymentIgnoredInstancesModification,
                "In instance group 'fake-instance-group', an attempt was made to remove a static ip " \
                'that is used by an ignored instance. This operation is not allowed.',
              )
            end
          end
        end

        context 'with multiple networks' do
          let(:desired_instance_count) { 4 }
          let(:instance_group_networks) do
            [
              { 'name' => 'a', 'static_ips' => a_static_ips, 'default' => %w[dns gateway] },
              { 'name' => 'b', 'static_ips' => b_static_ips },
            ]
          end

          context 'when all networks have static ips' do
            let(:a_static_ips) { ['192.168.1.10 - 192.168.1.11', '192.168.2.10 -192.168.2.11'] }
            let(:b_static_ips) { ['10.10.1.10 - 10.10.1.11', '10.10.2.10 - 10.10.2.11'] }

            context 'when all existing instances match specified static ips' do
              let(:existing_instances) do
                [
                  existing_instance_with_az_and_ips('zone1', ['192.168.1.10', '10.10.1.10']),
                  existing_instance_with_az_and_ips('zone2', ['192.168.2.10', '10.10.2.10']),
                  existing_instance_with_az_and_ips('zone1', ['192.168.1.11', '10.10.1.11']),
                  existing_instance_with_az_and_ips('zone2', ['192.168.2.11', '10.10.2.11']),
                ]
              end

              it 'reuses existing instances' do
                expect(new_instance_plans).to eq([])
                expect(obsolete_instance_plans).to eq([])
                expect(existing_instance_plans.size).to eq(4)

                expect(existing_instance_plans[0].desired_instance.az.name).to eq('zone1')
                expect(existing_instance_plans[0].network_plans.map(&:reservation).map(&:ip)).to match_array(
                  [ip_to_i('192.168.1.10'), ip_to_i('10.10.1.10')],
                )

                expect(existing_instance_plans[1].desired_instance.az.name).to eq('zone2')
                expect(existing_instance_plans[1].network_plans.map(&:reservation).map(&:ip)).to match_array(
                  [ip_to_i('192.168.2.10'), ip_to_i('10.10.2.10')],
                )

                expect(existing_instance_plans[2].desired_instance.az.name).to eq('zone1')
                expect(existing_instance_plans[2].network_plans.map(&:reservation).map(&:ip)).to match_array(
                  [ip_to_i('192.168.1.11'), ip_to_i('10.10.1.11')],
                )

                expect(existing_instance_plans[3].desired_instance.az.name).to eq('zone2')
                expect(existing_instance_plans[3].network_plans.map(&:reservation).map(&:ip)).to match_array(
                  [ip_to_i('192.168.2.11'), ip_to_i('10.10.2.11')],
                )
              end
            end

            context 'when some existing instances have IPs that are different from the instance group static IPs' do
              let(:existing_instances) do
                [
                  existing_instance_with_az_and_ips('zone1', ['192.168.1.10', '10.10.1.10']),
                  existing_instance_with_az_and_ips('zone2', ['192.168.2.14', '10.10.2.14']),
                  existing_instance_with_az_and_ips('zone1', ['192.168.1.14', '10.10.1.14']),
                  existing_instance_with_az_and_ips('zone2', ['192.168.2.11', '10.10.2.11']),
                ]
              end

              let(:a_static_ips) { ['192.168.1.10 - 192.168.1.11', '192.168.2.10 -192.168.2.11'] }
              let(:b_static_ips) { ['10.10.1.10', '10.10.1.12', '10.10.2.10 - 10.10.2.11'] }

              it 'keeps instances that match static IPs, and assigns new static IPs to instances with different IPs' do
                expect(new_instance_plans).to eq([])
                expect(obsolete_instance_plans).to eq([])
                expect(existing_instance_plans.size).to eq(4)

                expect(existing_instance_plans[0].desired_instance.az.name).to eq('zone1')
                expect(existing_instance_plans[0].network_plans.map(&:reservation).map(&:ip)).to match_array(
                  [ip_to_i('192.168.1.10'), ip_to_i('10.10.1.10')],
                )

                expect(existing_instance_plans[1].desired_instance.az.name).to eq('zone2')
                expect(existing_instance_plans[1].network_plans.map(&:reservation).map(&:ip)).to match_array(
                  [ip_to_i('192.168.2.11'), ip_to_i('10.10.2.11')],
                )

                expect(existing_instance_plans[2].desired_instance.az.name).to eq('zone2')
                expect(existing_instance_plans[2].network_plans.map(&:reservation).map(&:ip)).to match_array(
                  [ip_to_i('192.168.2.10'), ip_to_i('10.10.2.10')],
                )

                expect(existing_instance_plans[3].desired_instance.az.name).to eq('zone1')
                expect(existing_instance_plans[3].network_plans.map(&:reservation).map(&:ip)).to match_array(
                  [ip_to_i('192.168.1.11'), ip_to_i('10.10.1.12')],
                )
              end
            end

            context 'when existing instance static IPs no longer belong to one AZ' do
              let(:desired_instance_count) { 1 }
              let(:existing_instances) do
                [
                  existing_instance_with_az_and_ips('zone1', ['192.168.1.10', '10.10.2.10']),
                ]
              end
              let(:a_static_ips) { ['192.168.1.10'] }
              let(:b_static_ips) { ['10.10.1.10'] }

              it 'keeps static IP in the same AZ and picks new IP from same AZ' do
                expect(new_instance_plans).to eq([])
                expect(obsolete_instance_plans).to eq([])
                expect(existing_instance_plans.size).to eq(1)

                expect(existing_instance_plans[0].desired_instance.az.name).to eq('zone1')
                expect(existing_instance_plans[0].network_plans.map(&:reservation).map(&:ip)).to match_array(
                  [ip_to_i('192.168.1.10'), ip_to_i('10.10.1.10')],
                )
              end

              context 'when increasing number of instances' do
                let(:desired_instance_count) { 3 }
                let(:existing_instances) do
                  [
                    existing_instance_with_az_and_ips('zone1', ['192.168.1.10', '10.10.1.10']),
                    existing_instance_with_az_and_ips('zone1', ['192.168.1.11', '10.10.1.11']),
                  ]
                end
                let(:a_static_ips) { ['192.168.1.10 - 192.168.1.11', '192.168.2.10'] }
                let(:b_static_ips) { ['10.10.1.10 - 10.10.1.11', '10.10.2.10'] }

                it 'creates new instances in AZ with least instances' do
                  expect(new_instance_plans.size).to eq(1)
                  expect(new_instance_plans[0].desired_instance.az.name).to eq('zone2')
                  expect(new_instance_plans[0].network_plans.map(&:reservation).map(&:ip)).to match_array(
                    [ip_to_i('192.168.2.10'), ip_to_i('10.10.2.10')],
                  )
                  expect(obsolete_instance_plans).to eq([])
                  expect(existing_instance_plans.size).to eq(2)
                end
              end

              context 'when decreasing number of instances (number of static IPs is also decreased)' do
                let(:desired_instance_count) { 2 }
                let(:existing_instances) do
                  [
                    existing_instance_with_az_and_ips('zone1', ['192.168.1.10', '10.10.1.10']),
                    existing_instance_with_az_and_ips('zone1', ['192.168.1.11', '10.10.1.11']),
                    existing_instance_with_az_and_ips('zone2', ['192.168.2.10', '10.10.2.10']),
                  ]
                end
                let(:a_static_ips) { ['192.168.1.10', '192.168.2.10'] }
                let(:b_static_ips) { ['10.10.1.10', '10.10.2.10'] }

                it 'deletes instances with associated static ips' do
                  expect(new_instance_plans).to eq([])
                  expect(existing_instance_plans.size).to eq(2)
                  expect(existing_instance_plans.map(&:existing_instance)).to match_array([
                                                                                            existing_instances[0],
                                                                                            existing_instances[2],
                                                                                          ])

                  expect(obsolete_instance_plans.size).to eq(1)
                  expect(obsolete_instance_plans.first.existing_instance).to eq(existing_instances[1])
                end
              end
            end

            context 'when existing instance uses IPs needed by new instance' do
              let(:desired_instance_count) { 2 }

              let(:existing_instances) do
                [
                  existing_instance_with_az_and_ips('zone1', ['192.168.1.10', '10.10.2.10']),
                  existing_instance_with_az_and_ips('zone2', ['192.168.2.10', '10.10.2.11']),
                ]
              end
              let(:a_static_ips) { ['192.168.1.10', '192.168.2.10'] }
              let(:b_static_ips) { ['10.10.1.10', '10.10.2.10'] }

              it 'raises an error' do
                expect do
                  instance_plans
                end.to raise_error Bosh::Director::NetworkReservationError,
                                   'Failed to distribute static IPs to satisfy existing instance reservations'
              end
            end

            context 'when instance_group does not specify azs' do
              let(:networks_spec) do
                [
                  { 'name' => 'a',
                    'subnets' => [
                      make_subnet_spec('192.168.1.0/24', ['192.168.1.10 - 192.168.1.14'], nil),
                      make_subnet_spec('192.168.2.0/24', ['192.168.2.10 - 192.168.2.14'], nil),
                    ] },
                  { 'name' => 'b',
                    'subnets' => [
                      make_subnet_spec('10.10.1.0/24', ['10.10.1.10 - 10.10.1.14'], nil),
                      make_subnet_spec('10.10.2.0/24', ['10.10.2.10 - 10.10.2.14'], nil),
                    ] },
                ]
              end

              before do
                manifest_hash['instance_groups'].each { |entry| entry.delete('azs') }
                cloud_config_hash['compilation'].delete('az')
              end

              context 'when existing instances do not have AZs' do
                let(:desired_instance_count) { 2 }
                let(:existing_instances) do
                  [
                    existing_instance_with_az_and_ips(nil, ['192.168.1.10', '10.10.1.10']),
                    existing_instance_with_az_and_ips(nil, ['192.168.2.10', '10.10.2.11']),
                  ]
                end
                let(:a_static_ips) { ['192.168.1.10', '192.168.2.10'] }
                let(:b_static_ips) { ['10.10.1.10', '10.10.2.10'] }

                it 'does not assign AZs' do
                  expect(existing_instance_plans.map(&:desired_instance).map(&:az)).to eq([nil, nil])
                end
              end

              context 'when existing instances have AZs' do
                let(:existing_instances) do
                  [
                    existing_instance_with_az_and_ips('zone1', ['192.168.1.10', '10.10.1.10']),
                    existing_instance_with_az_and_ips('zone2', ['192.168.2.10', '10.10.2.11']),
                  ]
                end

                it 'raises an error' do
                  expect do
                    new_instance_plans
                  end.to raise_error(
                    Bosh::Director::NetworkReservationError,
                    "Existing instance 'fake-instance-group/#{existing_instances[0].index}' " \
                    "is using IP '192.168.1.10' in availability zone 'zone1'",
                  )
                end
              end
            end
          end

          context 'when instance IPs do not match at all' do
            let(:networks_spec) do
              [
                { 'name' => 'a',
                  'subnets' => [
                    make_subnet_spec('192.168.1.0/24', ['192.168.1.10 - 192.168.1.14'], ['zone1']),
                    make_subnet_spec('192.168.2.0/24', ['192.168.2.10 - 192.168.2.14'], %w[zone1 zone2]),
                  ] },
                { 'name' => 'b',
                  'subnets' => [
                    make_subnet_spec('10.10.1.0/24', ['10.10.1.10 - 10.10.1.14'], ['zone1']),
                    make_subnet_spec('10.10.2.0/24', ['10.10.2.10 - 10.10.2.14'], %w[zone1 zone2]),
                  ] },
              ]
            end
            let(:desired_instance_count) { 2 }
            let(:existing_instances) do
              [
                existing_instance_with_az_and_ips('zone1', ['192.168.5.10', '10.10.5.10']),
                existing_instance_with_az_and_ips('zone1', ['192.168.6.10', '10.10.6.11']),
              ]
            end
            let(:a_static_ips) { ['192.168.1.10', '192.168.2.10'] }
            let(:b_static_ips) { ['10.10.1.10', '10.10.2.10'] }

            it 'it reuses existing instances with new IPs in their AZs' do
              expect(new_instance_plans).to eq([])
              expect(existing_instance_plans.size).to eq(2)
              expect(existing_instance_plans[0].desired_instance.az.name).to eq('zone1')
              expect(existing_instance_plans[0].network_plans.map(&:reservation).map(&:ip)).to match_array(
                [ip_to_i('192.168.1.10'), ip_to_i('10.10.1.10')],
              )

              expect(existing_instance_plans[1].desired_instance.az.name).to eq('zone1')
              expect(existing_instance_plans[1].network_plans.map(&:reservation).map(&:ip)).to match_array(
                [ip_to_i('192.168.2.10'), ip_to_i('10.10.2.10')],
              )
            end
          end

          context 'when some networks do not have static ips' do
            let(:desired_instance_count) { 2 }
            let(:instance_group_networks) do
              [
                { 'name' => 'a', 'static_ips' => a_static_ips, 'default' => %w[dns gateway] },
                { 'name' => 'b' },
              ]
            end
            let(:existing_instances) do
              [
                existing_instance_with_az_and_ips('zone1', ['192.168.1.10', '192.168.2.10']),
              ]
            end
            let(:a_static_ips) { ['192.168.1.10 - 192.168.1.11'] }

            it 'creates network plans with dynamic reservations on network without static IP' do
              expect(new_instance_plans.size).to eq(1)
              expect(new_instance_plans[0].desired_instance.az.name).to eq('zone1')

              expect(new_instance_plans[0].network_plans.map(&:reservation).find(&:static?).ip).to eq(ip_to_i('192.168.1.11'))
              expect(new_instance_plans[0].network_plans.map(&:reservation).select(&:dynamic?).size).to eq(1)

              expect(obsolete_instance_plans).to eq([])

              expect(existing_instance_plans.size).to eq(1)
              expect(existing_instance_plans[0].desired_instance.az.name).to eq('zone1')
              expect(existing_instance_plans[0].network_plans.map(&:reservation).find(&:static?).ip).to eq(ip_to_i('192.168.1.10'))
              expect(existing_instance_plans[0].network_plans.map(&:reservation).select(&:dynamic?).size).to eq(1)
            end
          end

          context 'when networks are added or removed' do
            context 'when there are ignored instances' do
              let(:desired_instance_count) { 2 }
              let(:instance_group_networks) do
                [
                  { 'name' => 'a', 'static_ips' => a_static_ips, 'default' => %w[dns gateway] },
                  { 'name' => 'b' },
                ]
              end
              let(:a_static_ips) { ['192.168.1.10 - 192.168.1.11'] }

              let(:existing_instances) do
                [
                  existing_instance_with_az_and_ips('zone1', ['192.168.1.10', '192.168.2.10']),
                ]
              end

              it 'fails when attempting to add a network' do
                existing_instances.each do |instance|
                  instance.update(ignore: true)
                end

                expect do
                  instance_plans
                end.to raise_error(
                  Bosh::Director::DeploymentIgnoredInstancesModification,
                  "In instance group 'fake-instance-group', which contains ignored vms, " \
                  'an attempt was made to modify the networks. This operation is not allowed.',
                )
              end
            end
          end
        end

        context 'when network name was changed' do
          let(:desired_instance_count) { 2 }
          let(:instance_group_networks) { [{ 'name' => 'a', 'static_ips' => static_ips }] }
          let(:static_ips) { ['192.168.1.10', '192.168.2.10'] }
          let(:existing_instances) do
            [
              existing_instance_with_az_and_ips('zone1', ['192.168.1.10'], 'old-network-name'),
              existing_instance_with_az_and_ips('zone2', ['192.168.2.10'], 'old-network-name'),
            ]
          end

          it 'assigns azs based on IP addresses regardless' do
            expect(new_instance_plans).to eq([])
            expect(obsolete_instance_plans).to eq([])
            expect(existing_instance_plans.size).to eq(2)
            expect(existing_instance_plans[0].desired_instance.az.name).to eq('zone1')
            expect(existing_instance_plans[0].network_plans.map(&:reservation).map(&:ip)).to eq([ip_to_i('192.168.1.10')])
            expect(existing_instance_plans[1].desired_instance.az.name).to eq('zone2')
            expect(existing_instance_plans[1].network_plans.map(&:reservation).map(&:ip)).to eq([ip_to_i('192.168.2.10')])
          end

          it 'should fail if ignored instances belonged to that network' do
            existing_instances.each do |instance|
              instance.update(ignore: true)
            end

            expect do
              instance_plans
            end.to raise_error(
              Bosh::Director::DeploymentIgnoredInstancesModification,
              "In instance group 'fake-instance-group', which contains ignored vms, " \
              'an attempt was made to modify the networks. This operation is not allowed.',
            )
          end
        end
      end
    end

    def new_desired_instance
      DesiredInstance.new(instance_group, planner)
    end

    def existing_instance_with_az_and_ips(az, ips, network_name = 'a')
      instance = Bosh::Director::Models::Instance.make(
        availability_zone: az, deployment: deployment_model, job: instance_group.name,
      )
      ips.each do |ip|
        instance.add_ip_address(
          Bosh::Director::Models::IpAddress.make(
            address_str: NetAddr::CIDR.create(ip).to_i.to_s,
            network_name: network_name,
          ),
        )
      end
      instance
    end
  end
end
