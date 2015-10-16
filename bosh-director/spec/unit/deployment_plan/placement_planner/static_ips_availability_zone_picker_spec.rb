require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe PlacementPlanner::StaticIpsAvailabilityZonePicker do
    subject(:zone_picker) { PlacementPlanner::StaticIpsAvailabilityZonePicker.new }

    let(:cloud_config_hash) do
      {
        'networks' => [
          {'name' => 'a',
            'subnets' => [
              {
                'range' => '192.168.1.0/24',
                'gateway' => '192.168.1.1',
                'dns' => ['192.168.1.1', '192.168.1.2'],
                'static' => ['192.168.1.10 - 192.168.1.14'],
                'reserved' => [],
                'cloud_properties' => {},
                'availability_zone' => 'zone1'
              },
              {
                'range' => '192.168.2.0/24',
                'gateway' => '192.168.2.1',
                'dns' => ['192.168.2.1', '192.168.2.2'],
                'static' => ['192.168.2.10'],
                'reserved' => [],
                'cloud_properties' => {},
                'availability_zone' => 'zone2'
              }
            ]
          },
          {'name' => 'b',
            'subnets' => [
              {
                'range' => '10.10.1.0/24',
                'gateway' => '10.10.1.1',
                'dns' => ['10.10.1.1', '10.10.1.2'],
                'static' => ['10.10.1.10 - 10.10.1.14'],
                'reserved' => [],
                'cloud_properties' => {},
                'availability_zone' => 'zone1'
              },
              {
                'range' => '10.10.2.0/24',
                'gateway' => '10.10.2.1',
                'dns' => ['10.10.2.1', '10.10.2.2'],
                'static' => ['10.10.2.10'],
                'reserved' => [],
                'cloud_properties' => {},
                'availability_zone' => 'zone2'
              }
            ]
          }
        ],
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
        'availability_zones' => [
          {'name' => 'zone1', 'cloud_properties' => {:foo => 'bar'}},
          {'name' => 'zone2', 'cloud_properties' => {:foo => 'baz'}}
        ]}
    end
    let(:manifest_hash) do
      {
        'name' => 'simple',
        'director_uuid' => 'deadbeef',
        'releases' => [{'name' => 'bosh-release', 'version' => '0.1-dev'}],
        'update' => {'canaries' => 2, 'canary_watch_time' => 4000, 'max_in_flight' => 1, 'update_watch_time' => 20},
        'jobs' => [
          {
            'name' => 'foobar',
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

    let(:results) {zone_picker.place_and_match_in(availability_zones, job.networks, desired_instances, existing_instances, 'jobname')}
    let(:availability_zones) { job.availability_zones }
    let(:needed) {results[:desired_new]}
    let(:existing) {results[:desired_existing]}
    let(:obsolete) {results[:obsolete]}

    before do
      allow(deployment_manifest_migrator).to receive(:migrate) { |deployment_manifest, cloud_config| [deployment_manifest, cloud_config.manifest] }
    end

    describe '#place_and_match_in' do
      context 'with no existing instances' do
        let(:existing_instances) { [] }

        context 'when the subnets and the jobs do not specify availability zones' do
          let(:static_ips) { ['192.168.1.10 - 192.168.1.12'] }

          before do
            cloud_config_hash['networks'].each do |entry|
              entry['subnets'].each { |subnet| subnet.delete('availability_zone') }
            end
            manifest_hash['jobs'].each { |entry| entry.delete('availability_zones') }
          end

          it 'does not assign AZs' do
            results = zone_picker.place_and_match_in(job.availability_zones, job.networks, desired_instances, existing_instances, 'jobname')

            expect(needed.map(&:az)).to eq([nil, nil, nil])
          end
        end

        context 'when the job specifies a single network with all static IPs from a single AZ' do
          let(:static_ips) { ['192.168.1.10 - 192.168.1.12'] }

          it 'assigns instances to the AZ' do
            expect(needed.count).to eq(3)
            expect(existing).to eq([])
            expect(obsolete).to eq([])
            needed.each { |result| expect(result.az.name).to eq('zone1') }
          end
        end

        context 'when a job specifies a static ip that belongs to no subnet' do
          let(:static_ips) {['192.168.3.5']}
          let(:desired_instance_count) { 1 }

          it 'raises an exception' do
            expect{results}.to raise_error(Bosh::Director::JobNetworkInstanceIpMismatch, "Job 'jobname' declares static ip '192.168.3.5' which belongs to no subnet")
          end
        end

        context 'when the job specifies a single network with static IPs spanning multiple AZs' do
          let(:static_ips) { ['192.168.1.10', '192.168.1.11', '192.168.2.10'] }

          it 'assigns instances to the AZs' do
            expect(needed.count).to eq(3)
            expect(existing).to eq([])
            expect(obsolete).to eq([])

            expect(needed[0].az.name).to eq('zone1')
            expect(needed[1].az.name).to eq('zone1')
            expect(needed[2].az.name).to eq('zone2')
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
            expect(needed.count).to eq(2)
            expect(existing).to eq([])
            expect(obsolete).to eq([])

            expect(needed[0].az.name).to eq('zone1')
            expect(needed[1].az.name).to eq('zone1')
          end
        end

        context 'when the job specifies a static ip that is not in the list of job desired azs' do
          let(:static_ips) { ['192.168.1.10', '192.168.1.11', '192.168.2.10'] }
          let(:job_availability_zones) { ['zone1'] }

          it 'should raise' do
            expect{
              results
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

          it 'raises an error' do
            expect{ results }.to raise_error(
                Bosh::Director::JobNetworkInstanceIpMismatch,
                "Job 'jobname' networks must declare the same number of static IPs per AZ in each network"
              )
          end
        end
      end

      context 'when there are existing instances' do
        context 'when the subnets and the jobs do not specify availability zones' do
          let(:static_ips) { ['192.168.1.10 - 192.168.1.12'] }
          let(:existing_instances) { [
            existing_instance_with_az_and_ips(nil, []),
            existing_instance_with_az_and_ips(nil, []),
          ] }

          before do
            cloud_config_hash['networks'].each do |entry|
              entry['subnets'].each { |subnet| subnet.delete('availability_zone') }
            end
            manifest_hash['jobs'].each { |entry| entry.delete('availability_zones') }
          end

          it 'does not assign AZs' do
            expect(needed.map { |need| need.az }).to eq([nil])

            expect(existing.count).to eq(2)
            expect(existing[0][:desired_instance].az).to eq(nil)
            expect(existing[0][:existing_instance_model]).to be(existing_instances[0])

            expect(existing[1][:desired_instance].az).to eq(nil)
            expect(existing[1][:existing_instance_model]).to be(existing_instances[1])

            expect(obsolete).to eq([])
          end
        end

        context 'when the job specifies a single network with all static IPs from a single AZ with static IP that is outside of static range' do
          let(:static_ips) { ['192.168.1.10 - 192.168.1.12'] }
          let(:existing_instances) { [
            existing_instance_with_az_and_ips('zone2', []),
            existing_instance_with_az_and_ips('zone1', ['192.168.1.123']),
          ] }

          it 'assigns instances to the AZ' do
            expect(needed.map { |need| need.az.name }).to eq(['zone1', 'zone1'])

            expect(existing.count).to eq(1)
            expect(existing[0][:desired_instance].az.name).to eq('zone1')
            expect(existing[0][:existing_instance_model]).to be(existing_instances[1])

            expect(obsolete).to eq([existing_instances[0]])
          end
        end

        context 'when something' do
          let(:static_ips) { ['192.168.1.10', '192.168.2.10'] }
          let(:desired_instance_count) { 2 }
          let(:existing_instances) { [
            existing_instance_with_az_and_ips('zone1', ['192.168.1.11']),
            existing_instance_with_az_and_ips('zone1', ['192.168.1.10']),
          ] }

          it 'does the thing' do
            expect(needed.map { |need| need.az.name }).to eq(['zone2'])

            expect(existing.count).to eq(1)
            expect(existing[0][:desired_instance].az.name).to eq('zone1')
            expect(existing[0][:existing_instance_model]).to be(existing_instances[1])

            expect(obsolete).to eq([existing_instances[0]])
          end
        end

        context 'when the job specifies a single network with static IPs spanning multiple AZs' do
          let(:static_ips) { ['192.168.1.10', '192.168.1.11', '192.168.2.10'] }
          let(:existing_instances) { [
            existing_instance_with_az_and_ips('zone2', ['192.168.2.10']),
            existing_instance_with_az_and_ips('zone1', ['192.168.1.10']),
          ] }

          it 'assigns instances to the AZs' do
            expect(needed.map { |need| need.az.name }).to eq(['zone1'])

            expect(existing.count).to eq(2)
            expect(existing[0][:desired_instance].az.name).to eq('zone2')
            expect(existing[0][:existing_instance_model]).to be(existing_instances[0])
            expect(existing[1][:desired_instance].az.name).to eq('zone1')
            expect(existing[1][:existing_instance_model]).to be(existing_instances[1])

            expect(obsolete).to eq([])
          end
        end

        context 'when the job has existing instances with desired IPs' do
          let(:static_ips) { ['192.168.2.10', '192.168.1.11', '192.168.1.10'] }
          let(:existing_instances) { [
            existing_instance_with_az_and_ips('zone1', ['192.168.1.12']),
            existing_instance_with_az_and_ips('zone1', ['192.168.1.10']),
            existing_instance_with_az_and_ips('zone1', ['192.168.1.11'])
          ] }

          it 'only reuses instances that have desired IPs' do
            expect(needed.map { |need| need.az.name }).to eq(['zone2'])

            expect(existing.count).to eq(2)
            expect(existing.map { |i| i[:desired_instance].az.name }).to eq(['zone1', 'zone1'])
            expect(existing.map { |i| i[:existing_instance_model] }).to match_array([existing_instances[1], existing_instances[2]])

            expect(obsolete).to eq([existing_instances[0]])
          end
        end

        context 'when scaling down' do
          let(:desired_instance_count) { 1 }

          let(:static_ips) { ['192.168.1.11'] }
          let(:existing_instances) { [
            existing_instance_with_az_and_ips('zone1', ['192.168.1.12']),
            existing_instance_with_az_and_ips('zone1', ['192.168.1.10']),
            existing_instance_with_az_and_ips('zone1', ['192.168.1.11'])
          ] }

          it 'only reuses instances that have desired IPs' do
            expect(needed).to eq([])
            expect(existing.map { |i| i[:desired_instance].az.name }).to eq(['zone1'])
            expect(existing.map { |i| i[:existing_instance_model] }).to match_array([existing_instances[2]])
            expect(obsolete).to eq([existing_instances[0], existing_instances[1]])
          end
        end

        context 'when the job has existing instances with IPs from multiple networks' do
          let(:desired_instance_count) { 1 }

          let(:static_ips) { ['192.168.1.11'] }
          let(:static_ips_net_b) { ['10.10.1.10'] }
          let(:job_networks) { [
            {'name' => 'a', 'static_ips' => static_ips, 'default' => ['dns', 'gateway']},
            {'name' => 'b', 'static_ips' => static_ips_net_b}
          ] }

          context 'when all existing instance IPs match desired IPs' do
            let(:existing_instances) { [
              existing_instance_with_az_and_ips('zone1', ['192.168.1.11', '10.10.1.10']),
            ] }

            it 'reuses existing instance' do
              expect(needed.count).to eq(0)

              expect(existing.count).to eq(1)
              expect(existing[0][:desired_instance].az.name).to eq('zone1')
              expect(existing[0][:existing_instance_model]).to eq(existing_instances[0])

              expect(obsolete).to eq([])
            end
          end

          context 'when not all existing instance IPs match desired IPs' do
            let(:existing_instances) { [
              existing_instance_with_az_and_ips('zone1', ['192.168.1.12', '10.10.1.10']),
            ] }

            it 'marks existing instance as obsolete' do
              skip 'Multiple networks are not supported with availability_zones yet'
              expect(needed.count).to eq(1)
              expect(needed[0].az.name).to eq('zone1')

              expect(existing.count).to eq(0)
              expect(obsolete).to eq([existing_instances[0]])
            end
          end
        end

        context 'when the job specifies multiple networks with static IPs from the same AZ' do
          let(:desired_instance_count) { 2 }
          let(:existing_instances) { [
            existing_instance_with_az_and_ips('zone2', ['10.10.1.15']),
            existing_instance_with_az_and_ips('zone1', ['192.168.1.10']),
          ] }

          let(:job_networks) do
            [
              {'name' => 'a', 'static_ips' => ['192.168.1.10', '192.168.1.11'], 'default' => ['dns', 'gateway']},
              {'name' => 'b', 'static_ips' => ['10.10.1.10', '10.10.1.11']}
            ]
          end

          it 'assigns instances to the AZ' do
            expect(needed.map { |need| need.az.name }).to eq(['zone1'])

            expect(existing.count).to eq(1)
            expect(existing[0][:desired_instance].az.name).to eq('zone1')
            expect(existing[0][:existing_instance_model]).to be(existing_instances[1])

            expect(obsolete).to eq([existing_instances[0]])
          end
        end

        context 'and the job is non-AZ legacy' do
          let(:static_ips) { ['192.168.1.10 - 192.168.1.12'] }
          let(:existing_instances) { [
            existing_instance_with_az_and_ips(nil, []),
            existing_instance_with_az_and_ips(nil, []),
          ] }
          let(:availability_zones) { [] }

          it 'does not assign AZs' do
            expect(needed.map { |need| need.az }).to eq([nil])

            expect(existing.count).to eq(2)
            expect(existing[0][:desired_instance].az).to eq(nil)
            expect(existing[0][:existing_instance_model]).to be(existing_instances[0])
            expect(existing[1][:desired_instance].az).to eq(nil)
            expect(existing[1][:existing_instance_model]).to be(existing_instances[1])

            expect(obsolete).to eq([])
          end
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
