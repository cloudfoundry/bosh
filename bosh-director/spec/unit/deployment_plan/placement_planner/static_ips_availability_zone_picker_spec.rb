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
            'availability_zones' => ['zone1', 'zone2']
          }
        ]
      }
    end
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

    let(:results) {zone_picker.place_and_match_in(availability_zones, job.networks, desired_instances, existing_instances)}
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
            results = zone_picker.place_and_match_in(job.availability_zones, job.networks, desired_instances, existing_instances)

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
      end

      context 'when there are existing instances' do
        context 'when the subnets and the jobs do not specify availability zones' do
          let(:static_ips) { ['192.168.1.10 - 192.168.1.12'] }
          let(:existing_instances) { [
            existing_instance_with_az(1, nil),
            existing_instance_with_az(2, nil),
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
            expect(existing[0][:existing_instance_model]).to be(existing_instances[0].model)
            expect(existing[1][:desired_instance].az).to eq(nil)
            expect(existing[1][:existing_instance_model]).to be(existing_instances[1].model)

            expect(obsolete).to eq([])
          end
        end

        context 'when the job specifies a single network with all static IPs from a single AZ' do
          let(:static_ips) { ['192.168.1.10 - 192.168.1.12'] }
          let(:existing_instances) { [
            existing_instance_with_az(1, 'zone2'),
            existing_instance_with_az(2, 'zone1'),
          ] }

          it 'assigns instances to the AZ' do
            expect(needed.map { |need| need.az.name }).to eq(['zone1', 'zone1'])

            expect(existing.count).to eq(1)
            expect(existing[0][:desired_instance].az.name).to eq('zone1')
            expect(existing[0][:existing_instance_model]).to be(existing_instances[1].model)

            expect(obsolete).to eq([existing_instances[0].model])
          end
        end

        context 'when the job specifies a single network with static IPs spanning multiple AZs' do
          let(:static_ips) { ['192.168.1.10', '192.168.1.11', '192.168.2.10'] }
          let(:existing_instances) { [
            existing_instance_with_az(1, 'zone2'),
            existing_instance_with_az(2, 'zone1'),
          ] }

          it 'assigns instances to the AZs' do
            expect(needed.map { |need| need.az.name }).to eq(['zone1'])

            expect(existing.count).to eq(2)
            expect(existing[0][:desired_instance].az.name).to eq('zone1')
            expect(existing[0][:existing_instance_model]).to be(existing_instances[1].model)
            expect(existing[1][:desired_instance].az.name).to eq('zone2')
            expect(existing[1][:existing_instance_model]).to be(existing_instances[0].model)

            expect(obsolete).to eq([])
          end
        end

        context 'when the job specifies multiple networks with static IPs from the same AZ' do
          let(:desired_instance_count) { 2 }
          let(:existing_instances) { [
            existing_instance_with_az(1, 'zone2'),
            existing_instance_with_az(2, 'zone1'),
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
            expect(existing[0][:existing_instance_model]).to be(existing_instances[1].model)

            expect(obsolete).to eq([existing_instances[0].model])
          end
        end

        context 'and the job is non-AZ legacy' do
          let(:static_ips) { ['192.168.1.10 - 192.168.1.12'] }
          let(:existing_instances) { [
            existing_instance_with_az(1, nil),
            existing_instance_with_az(2, nil),
          ] }
          let(:availability_zones) { [] }

          it 'does not assign AZs' do
            expect(needed.map { |need| need.az }).to eq([nil])

            expect(existing.count).to eq(2)
            expect(existing[0][:desired_instance].az).to eq(nil)
            expect(existing[0][:existing_instance_model]).to be(existing_instances[0].model)
            expect(existing[1][:desired_instance].az).to eq(nil)
            expect(existing[1][:existing_instance_model]).to be(existing_instances[1].model)

            expect(obsolete).to eq([])
          end
        end
      end
    end

    def new_desired_instance
      DesiredInstance.new(job, 'started', planner)
    end

    def existing_instance_with_az(index, az)
      InstanceWithAZ.new(Bosh::Director::Models::Instance.make(index: index), az)
    end
  end
end
