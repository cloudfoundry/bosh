require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe PlacementPlanner::StaticAvailabilityZonePicker2 do
    include Bosh::Director::IpUtil

    subject(:zone_picker) { PlacementPlanner::StaticAvailabilityZonePicker2.new }
    def make_subnet_spec(range, static_ips, zone_names)
      {
        'range' => range,
        'gateway' => NetAddr::CIDR.create(range)[1].ip,
        'dns' => ['8.8.8.8'],
        'static' => static_ips,
        'reserved' => [],
        'cloud_properties' => {},
        'availability_zones' => zone_names
      }
    end
    let(:networks_spec) do
      [
        {'name' => 'a',
          'subnets' => [
            make_subnet_spec('192.168.1.0/24', ['192.168.1.10 - 192.168.1.14'], ['zone1']),
            make_subnet_spec('192.168.2.0/24', ['192.168.2.10 - 192.168.2.14'], ['zone2']),
          ]
        },
        {'name' => 'b',
          'subnets' => [
            make_subnet_spec('10.10.1.0/24', ['10.10.1.10 - 10.10.1.14'], ['zone1']),
            make_subnet_spec('10.10.2.0/24', ['10.10.2.10 - 10.10.2.14'], ['zone2']),
          ]
        }
      ]
    end

    let(:cloud_config_hash) do
      {
        'networks' => networks_spec,
        'compilation' => {'workers' => 1, 'network' => 'a', 'cloud_properties' => {}},
        'resource_pools' => [
          {
            'name' => 'a',
            'size' => 3,
            'cloud_properties' => {},
            'network' => 'a',
            'stemcell' => {'name' => 'ubuntu-stemcell', 'version' => '1'}
          }
        ],
        'availability_zones' => cloud_config_availabilty_zones}
    end
    let(:cloud_config_availabilty_zones) do
      [
        {'name' => 'zone1', 'cloud_properties' => {:foo => 'bar'}},
        {'name' => 'zone2', 'cloud_properties' => {:foo => 'baz'}}
      ]
    end
    let(:manifest_hash) do
      {
        'name' => 'simple',
        'director_uuid' => 'deadbeef',
        'releases' => [{'name' => 'bosh-release', 'version' => '0.1-dev'}],
        'update' => {'canaries' => 2, 'canary_watch_time' => 4000, 'max_in_flight' => 1, 'update_watch_time' => 20},
        'jobs' => [
          {
            'name' => 'fake-job',
            'templates' => [{'name' => 'foobar'}],
            'resource_pool' => 'a',
            'instances' => desired_instance_count,
            'networks' => job_networks,
            'properties' => {},
            'availability_zones' => job_availability_zones
          }
        ]
      }
    end
    let(:job_availability_zones) { ['zone1', 'zone2'] }
    let(:deployment_manifest_migrator) { instance_double(ManifestMigrator) }
    let(:planner_factory) { PlannerFactory.new(deployment_manifest_migrator, deployment_repo, event_log, logger) }
    let(:deployment_repo) { DeploymentRepo.new }
    let(:event_log) { Bosh::Director::EventLog::Log.new(StringIO.new('')) }
    let(:cloud_config_model) { Bosh::Director::Models::CloudConfig.make(manifest: cloud_config_hash) }
    let(:planner) { planner_factory.create_from_manifest(manifest_hash, cloud_config_model, {}) }
    let(:job) { planner.jobs.first }
    let(:job_networks) { [{'name' => 'a', 'static_ips' => static_ips}] }
    let(:desired_instances) { [].tap { |a| desired_instance_count.times { a << new_desired_instance } } }
    let(:desired_instance_count) { 3 }

    let(:instance_plans) { zone_picker.place_and_match_in(availability_zones, job.networks, desired_instances, existing_instances, 'fake-job')}
    let(:availability_zones) { job.availability_zones }
    let(:new_instance_plans) { instance_plans.select(&:new?) }
    let(:existing_instance_plans) { instance_plans.reject(&:new?).reject(&:obsolete?) }
    let(:obsolete_instance_plans) { instance_plans.select(&:obsolete?) }

    before do
      allow(deployment_manifest_migrator).to receive(:migrate) { |deployment_manifest, cloud_config| [deployment_manifest, cloud_config.manifest] }
    end

    describe '#place_and_match_in' do
      context 'with no existing instances' do
        let(:existing_instances) { [] }
        let(:static_ips) { ['192.168.1.10 - 192.168.1.12'] }

        context 'when the subnets and the jobs do not specify availability zones' do
          before do
            cloud_config_hash['networks'].each do |entry|
              entry['subnets'].each { |subnet| subnet.delete('availability_zone') }
            end
            manifest_hash['jobs'].each { |entry| entry.delete('availability_zones') }
          end

          xit 'does not assign AZs' do
            results = zone_picker.place_and_match_in(job.availability_zones, job.networks, desired_instances, existing_instances, 'jobname')

            expect(needed.map(&:az)).to eq([nil, nil, nil])
          end
        end

        context 'when job does not specify azs and the subnets do' do
          before do
            manifest_hash['jobs'].each { |entry| entry.delete('availability_zones') }
          end

          xit 'raises' do
            expect {
              results.inspect
            }.to raise_error(
                Bosh::Director::JobInvalidAvailabilityZone,
                "Job 'jobname' subnets declare availability zones and the job does not"
              )
          end
        end

        context 'when the job specifies a single network with all static IPs from a single AZ' do
          let(:static_ips) { ['192.168.1.10 - 192.168.1.12'] }

          it 'assigns instances to the AZ' do
            expect(new_instance_plans.size).to eq(3)
            expect(existing_instance_plans).to eq([])
            expect(obsolete_instance_plans).to eq([])
            expect(new_instance_plans.map(&:desired_instance).map(&:az).map(&:name)).to eq(['zone1', 'zone1', 'zone1'])
            expect(new_instance_plans.map(&:network_plans).flatten.map(&:reservation).map(&:ip)).to eq(
                [ip_to_i('192.168.1.10'), ip_to_i('192.168.1.11'), ip_to_i('192.168.1.12')]
              )
          end
        end

        context 'when a job specifies a static ip that belongs to no subnet' do
          let(:static_ips) {['192.168.3.5']}
          let(:desired_instance_count) { 1 }

          it 'raises an exception' do
            expect{instance_plans}.to raise_error(Bosh::Director::JobNetworkInstanceIpMismatch, "Job 'fake-job' declares static ip '192.168.3.5' which belongs to no subnet")
          end
        end

        context 'when the job specifies a single network with static IPs spanning multiple AZs' do
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

        context 'when the job specifies multiple networks with static IPs from the same AZ' do
          let(:desired_instance_count) { 2 }
          let(:job_networks) do
            [
              {'name' => 'a', 'static_ips' => ['192.168.1.10', '192.168.1.11'], 'default' => ['dns', 'gateway']},
              {'name' => 'b', 'static_ips' => ['10.10.1.10', '10.10.1.11']}
            ]
          end

          it 'assigns instances to the AZ' do
            expect(new_instance_plans.size).to eq(2)
            expect(existing_instance_plans).to eq([])
            expect(obsolete_instance_plans).to eq([])

            expect(new_instance_plans[0].desired_instance.az.name).to eq('zone1')
            expect(new_instance_plans[0].network_plans.map(&:reservation).map(&:ip)).to eq(
                [ip_to_i('192.168.1.10'), ip_to_i('10.10.1.10')]
              )

            expect(new_instance_plans[1].desired_instance.az.name).to eq('zone1')
            expect(new_instance_plans[1].network_plans.map(&:reservation).map(&:ip)).to eq(
                [ip_to_i('192.168.1.11'), ip_to_i('10.10.1.11')]
              )
          end
        end

        context 'when the job specifies multiple networks with static IPs from different non-overlapping AZs' do
          let(:desired_instance_count) { 2 }
          let(:job_networks) do
            [
              {'name' => 'a', 'static_ips' => ['192.168.1.10', '192.168.2.10'], 'default' => ['dns', 'gateway']},
              {'name' => 'b', 'static_ips' => ['10.10.1.10', '10.10.2.10']}
            ]
          end

          it 'assigns instances to different AZs' do
            expect(new_instance_plans.size).to eq(2)
            expect(existing_instance_plans).to eq([])
            expect(obsolete_instance_plans).to eq([])

            expect(new_instance_plans[0].desired_instance.az.name).to eq('zone1')
            expect(new_instance_plans[0].network_plans.map(&:reservation).map(&:ip)).to eq(
                [ip_to_i('192.168.1.10'), ip_to_i('10.10.1.10')]
              )

            expect(new_instance_plans[1].desired_instance.az.name).to eq('zone2')
            expect(new_instance_plans[1].network_plans.map(&:reservation).map(&:ip)).to eq(
                [ip_to_i('192.168.2.10'), ip_to_i('10.10.2.10')]
              )
          end
        end

        context 'when job specifies multiple networks with static IPs from different overlapping AZs' do
          let(:desired_instance_count) { 4 }
          let(:job_networks) do
            [
              {'name' => 'a', 'static_ips' => ['192.168.1.10-192.168.1.12', '192.168.2.10'], 'default' => ['dns', 'gateway']},
              {'name' => 'b', 'static_ips' => ['10.10.1.10 - 10.10.1.11', '10.10.2.10-10.10.2.11']},
              {'name' => 'c', 'static_ips' => ['172.16.1.10', '172.16.2.10-172.16.2.12']},
              {'name' => 'd', 'static_ips' => ['64.8.1.10', '64.8.2.10', '64.8.3.10-64.8.3.11']},
            ]
          end
          let(:job_availability_zones) { ['z1', 'z2', 'z3', 'z4'] }
          let(:networks_spec) do
            [
              {'name' => 'a',
                'subnets' => [
                  make_subnet_spec('192.168.1.0/24', ['192.168.1.10 - 192.168.1.14'], ['z1', 'z2', 'z3']),
                  make_subnet_spec('192.168.2.0/24', ['192.168.2.10 - 192.168.2.14'], ['z4']),
                ]
              },
              {'name' => 'b',
                'subnets' => [
                  make_subnet_spec('10.10.1.0/24', ['10.10.1.10 - 10.10.1.14'], ['z1', 'z2']),
                  make_subnet_spec('10.10.2.0/24', ['10.10.2.10 - 10.10.2.14'], ['z3', 'z4']),
                ]
              },
              {'name' => 'c',
                'subnets' => [
                  make_subnet_spec('172.16.1.0/24', ['172.16.1.10 - 172.16.1.14'], ['z1']),
                  make_subnet_spec('172.16.2.0/24', ['172.16.2.10 - 172.16.2.14'], ['z2', 'z3', 'z4']),
                ]
              },
              {'name' => 'd',
                'subnets' => [
                  make_subnet_spec('64.8.1.0/24', ['64.8.1.10 - 64.8.1.14'], ['z1']),
                  make_subnet_spec('64.8.2.0/24', ['64.8.2.10 - 64.8.2.14'], ['z2']),
                  make_subnet_spec('64.8.3.0/24', ['64.8.3.10 - 64.8.3.14'], ['z3', 'z4']),
                ]
              }
            ]
          end
          let(:cloud_config_availabilty_zones) do
            [{'name' => 'z1'}, {'name' => 'z2'}, {'name' => 'z3'}, {'name' => 'z4'}]
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

            expect(new_instance_plans.map(&:desired_instance).map(&:az).map(&:name)).to match_array(['z1', 'z2', 'z3', 'z4'])
          end
        end

        context 'when the job specifies a static ip that is not in the list of job desired azs' do
          let(:static_ips) { ['192.168.1.10', '192.168.1.11', '192.168.2.10'] }
          let(:job_availability_zones) { ['zone1'] }

          xit 'should raise' do
            expect{
              instance_plans
            }.to raise_error(
                Bosh::Director::JobStaticIpsFromInvalidAvailabilityZone,
                "Job 'jobname' declares static ip '192.168.2.10' which does not belong to any of the job's availability zones."
              )
          end
        end

        context 'when job static IP counts for each AZ in networks do not match' do
          let(:desired_instance_count) { 2 }
          let(:job_networks) do
            [
              {'name' => 'a', 'static_ips' => ['192.168.1.10', '192.168.2.10'], 'default' => ['dns', 'gateway']},
              {'name' => 'b', 'static_ips' => ['10.10.1.10', '10.10.1.11']}
            ]
          end

          xit 'raises an error' do
            expect{ results }.to raise_error(
                Bosh::Director::JobNetworkInstanceIpMismatch,
                "Job 'jobname' networks must declare the same number of static IPs per AZ in each network"
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
            let(:job_availability_zones) { ['zone1'] }

            before do
              cloud_config_hash['networks'].first['subnets'][1]['availability_zones'] = ['zone1']
            end

            it 'reuses instances with new AZ' do
              expect(new_instance_plans).to eq([])
              expect(obsolete_instance_plans).to eq([])
              expect(existing_instance_plans.size).to eq(2)
              expect(existing_instance_plans[0].desired_instance.az.name).to eq('zone1')
              expect(existing_instance_plans[0].network_plans.map(&:reservation).map(&:ip)).to eq([ip_to_i('192.168.1.10')])
              expect(existing_instance_plans[1].desired_instance.az.name).to eq('zone1')
              expect(existing_instance_plans[1].network_plans.map(&:reservation).map(&:ip)).to eq([ip_to_i('192.168.2.10')])
            end
          end

          context 'when existing instance static IP is no longer in the list of job static ips' do
            let(:desired_instance_count) { 2 }
            let(:static_ips) { ['192.168.1.14', '192.168.2.14'] }
            let(:existing_instances) do
              [
                existing_instance_with_az_and_ips('zone1', ['192.168.1.10']),
                existing_instance_with_az_and_ips('zone2', ['192.168.2.10']),
              ]
            end
            let(:job_availability_zones) { ['zone1', 'zone2'] }

            it 'picks new IP for instance that is not used by other instances' do
              expect(new_instance_plans).to eq([])
              expect(obsolete_instance_plans).to eq([])
              expect(existing_instance_plans.size).to eq(2)
              expect(existing_instance_plans[0].desired_instance.az.name).to eq('zone1')
              expect(existing_instance_plans[0].network_plans.map(&:reservation).map(&:ip)).to eq([ip_to_i('192.168.1.14')])
              expect(existing_instance_plans[1].desired_instance.az.name).to eq('zone2')
              expect(existing_instance_plans[1].network_plans.map(&:reservation).map(&:ip)).to eq([ip_to_i('192.168.2.14')])
            end
          end

          context 'when subnet specifies several AZs (static IP belongs to several AZs)' do
            let(:desired_instance_count) { 1 }
            let(:networks_spec) do
              [
                {'name' => 'a',
                  'subnets' => [
                    make_subnet_spec('192.168.1.0/24', ['192.168.1.10 - 192.168.1.14'], new_subnet_azs),
                  ]
                }
              ]
            end
            let(:new_subnet_azs) { ['zone2', 'zone1'] }
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
              let(:job_availability_zones) { ['zone2'] }

              it 'reuses instance with new AZ from same subnet' do
                expect(new_instance_plans).to eq([])
                expect(obsolete_instance_plans).to eq([])
                expect(existing_instance_plans.size).to eq(1)
                expect(existing_instance_plans[0].desired_instance.az.name).to eq('zone2')
                expect(existing_instance_plans[0].network_plans.map(&:reservation).map(&:ip)).to eq([ip_to_i('192.168.1.10')])
              end
            end
          end
        end

        context 'with multiple networks' do
          let(:desired_instance_count) { 4 }
          let(:job_networks) do
            [
              {'name' => 'a', 'static_ips' => a_static_ips, 'default' => ['dns', 'gateway']},
              {'name' => 'b', 'static_ips' => b_static_ips}
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
                  [ip_to_i('192.168.1.10'), ip_to_i('10.10.1.10')]
                )

                expect(existing_instance_plans[1].desired_instance.az.name).to eq('zone2')
                expect(existing_instance_plans[1].network_plans.map(&:reservation).map(&:ip)).to match_array(
                  [ip_to_i('192.168.2.10'), ip_to_i('10.10.2.10')]
                )

                expect(existing_instance_plans[2].desired_instance.az.name).to eq('zone1')
                expect(existing_instance_plans[2].network_plans.map(&:reservation).map(&:ip)).to match_array(
                  [ip_to_i('192.168.1.11'), ip_to_i('10.10.1.11')]
                )

                expect(existing_instance_plans[3].desired_instance.az.name).to eq('zone2')
                expect(existing_instance_plans[3].network_plans.map(&:reservation).map(&:ip)).to match_array(
                  [ip_to_i('192.168.2.11'), ip_to_i('10.10.2.11')]
                )
              end
            end

            context 'when some existing instances have IPs that are different from job static IPs' do
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
                    [ip_to_i('192.168.1.10'), ip_to_i('10.10.1.10')]
                  )

                expect(existing_instance_plans[1].desired_instance.az.name).to eq('zone2')
                expect(existing_instance_plans[1].network_plans.map(&:reservation).map(&:ip)).to match_array(
                    [ip_to_i('192.168.2.11'), ip_to_i('10.10.2.11')]
                  )

                expect(existing_instance_plans[2].desired_instance.az.name).to eq('zone1')
                expect(existing_instance_plans[2].network_plans.map(&:reservation).map(&:ip)).to match_array(
                    [ip_to_i('192.168.1.11'), ip_to_i('10.10.1.12')]
                  )

                expect(existing_instance_plans[3].desired_instance.az.name).to eq('zone2')
                expect(existing_instance_plans[3].network_plans.map(&:reservation).map(&:ip)).to match_array(
                    [ip_to_i('192.168.2.10'), ip_to_i('10.10.2.10')]
                  )
              end
            end

            context 'when existing instances have static IP on different AZ' do
              let(:existing_instances) do
                [
                  existing_instance_with_az_and_ips('zone2', ['192.168.1.10', '10.10.1.10']),
                  existing_instance_with_az_and_ips('zone2', ['192.168.1.11', '10.10.1.11']),
                  existing_instance_with_az_and_ips('zone1', ['192.168.2.10', '10.10.2.10']),
                  existing_instance_with_az_and_ips('zone2', ['192.168.2.11', '10.10.2.11']),
                ]
              end

              it 'keeps instances with static IPs but moves them to different AZs' do
                expect(new_instance_plans).to eq([])
                expect(obsolete_instance_plans).to eq([])
                expect(existing_instance_plans.size).to eq(4)

                expect(existing_instance_plans[0].desired_instance.az.name).to eq('zone1')
                expect(existing_instance_plans[0].network_plans.map(&:reservation).map(&:ip)).to match_array(
                    [ip_to_i('192.168.1.10'), ip_to_i('10.10.1.10')]
                  )

                expect(existing_instance_plans[1].desired_instance.az.name).to eq('zone1')
                expect(existing_instance_plans[1].network_plans.map(&:reservation).map(&:ip)).to match_array(
                    [ip_to_i('192.168.1.11'), ip_to_i('10.10.1.11')]
                  )

                expect(existing_instance_plans[2].desired_instance.az.name).to eq('zone2')
                expect(existing_instance_plans[2].network_plans.map(&:reservation).map(&:ip)).to match_array(
                    [ip_to_i('192.168.2.10'), ip_to_i('10.10.2.10')]
                  )

                expect(existing_instance_plans[3].desired_instance.az.name).to eq('zone2')
                expect(existing_instance_plans[3].network_plans.map(&:reservation).map(&:ip)).to match_array(
                    [ip_to_i('192.168.2.11'), ip_to_i('10.10.2.11')]
                  )
              end
            end

            context 'when existing instance static IPs no longer belong to one AZ' do
              let(:desired_instance_count) { 1 }
              let(:existing_instances) do
                [
                  existing_instance_with_az_and_ips('zone1', ['192.168.1.10', '10.10.2.10'])
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
                    [ip_to_i('192.168.1.10'), ip_to_i('10.10.1.10')]
                  )
              end

              context 'when increasing number of instances' do
                let(:desired_instance_count) { 3 }
                let(:existing_instances) do
                  [
                    existing_instance_with_az_and_ips('zone1', ['192.168.1.10', '10.10.1.10']),
                    existing_instance_with_az_and_ips('zone1', ['192.168.1.11', '10.10.1.11'])
                  ]
                end
                let(:a_static_ips) { ['192.168.1.10 - 192.168.1.11', '192.168.2.10'] }
                let(:b_static_ips) { ['10.10.1.10 - 10.10.1.11', '10.10.2.10'] }

                it 'creates new instances in AZ with least instances' do
                  expect(new_instance_plans.size).to eq(1)
                  expect(new_instance_plans[0].desired_instance.az.name).to eq('zone2')
                  expect(new_instance_plans[0].network_plans.map(&:reservation).map(&:ip)).to match_array(
                      [ip_to_i('192.168.2.10'), ip_to_i('10.10.2.10')]
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
                    existing_instance_with_az_and_ips('zone2', ['192.168.2.10', '10.10.2.10'])
                  ]
                end
                let(:a_static_ips) { ['192.168.1.10', '192.168.2.10'] }
                let(:b_static_ips) { ['10.10.1.10', '10.10.2.10'] }

                it 'deletes instances with associated static ips' do
                  expect(new_instance_plans).to eq([])
                  expect(existing_instance_plans.size).to eq(2)
                  expect(existing_instance_plans.map(&:existing_instance)).to match_array([
                    existing_instances[0],
                    existing_instances[2]
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
                  existing_instance_with_az_and_ips('zone2', ['192.168.2.10', '10.10.2.11'])
                ]
              end
              let(:a_static_ips) { ['192.168.1.10', '192.168.2.10'] }
              let(:b_static_ips) { ['10.10.1.10', '10.10.2.10'] }

              it 'raises an error' do
                expect {
                  instance_plans
                }.to raise_error Bosh::Director::NetworkReservationError,
                    'Failed to distribute static IPs to satisfy existing instance reservations'
              end
            end
          end

          context 'when instance IPs do not match at all' do
            let(:desired_instance_count) { 2 }
            let(:existing_instances) do
              [
                existing_instance_with_az_and_ips('zone1', ['192.168.5.10', '10.10.5.10']),
                existing_instance_with_az_and_ips('zone1', ['192.168.6.10', '10.10.6.11'])
              ]
            end
            let(:a_static_ips) { ['192.168.1.10', '192.168.2.10'] }
            let(:b_static_ips) { ['10.10.1.10', '10.10.2.10'] }

            it 'puts that instance in AZ with least number of instances' do
              expect(new_instance_plans).to eq([])
              expect(existing_instance_plans.size).to eq(2)
              expect(existing_instance_plans[0].desired_instance.az.name).to eq('zone1')
              expect(existing_instance_plans[0].network_plans.map(&:reservation).map(&:ip)).to match_array(
                  [ip_to_i('192.168.1.10'), ip_to_i('10.10.1.10')]
                )

              expect(existing_instance_plans[1].desired_instance.az.name).to eq('zone2')
              expect(existing_instance_plans[1].network_plans.map(&:reservation).map(&:ip)).to match_array(
                  [ip_to_i('192.168.2.10'), ip_to_i('10.10.2.10')]
                )
            end
          end

          context 'when some networks do not have static ips' do
            let(:desired_instance_count) { 2 }
            let(:job_networks) do
              [
                {'name' => 'a', 'static_ips' => a_static_ips, 'default' => ['dns', 'gateway']},
                {'name' => 'b'}
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

          context 'when subnet specifies several AZs' do

          end
        end

        context 'when there are more existing instances than desired instances' do
          it 'creates obsolete instance plans'
        end

        context 'when there are more desired instance than existing instances' do
          it 'prefers AZs for desired instances that do not have existing instances' do

          end
        end

        context 'when job does not specify availability_zones' do

        end
      end
    end

    def new_desired_instance
      DesiredInstance.new(job, 'started', planner)
    end

    def existing_instance_with_az_and_ips(az, ips)
      instance = Bosh::Director::Models::Instance.make(availability_zone: az)
      ips.each do |ip|
        instance.add_ip_address(Bosh::Director::Models::IpAddress.make(address: NetAddr::CIDR.create(ip).to_i))
      end
      instance
    end
  end
end
