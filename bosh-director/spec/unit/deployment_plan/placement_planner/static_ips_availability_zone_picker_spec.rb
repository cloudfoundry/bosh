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
        'releases' =>[{'name' => 'bosh-release', 'version' => '0.1-dev'}],
        'update' =>{'canaries' =>2, 'canary_watch_time' =>4000, 'max_in_flight' =>1, 'update_watch_time' =>20},
        'jobs' =>[
          {
            'name' => 'foobar',
            'templates' =>[{'name' => 'foobar'}],
            'resource_pool' => 'a',
            'instances' =>3,
            'networks' => job_networks,
            'properties' =>{},
            'availability_zones' =>['zone1', 'zone2']
          }
        ]
      }
    end
    let(:canonicalizer) { Class.new { include Bosh::Director::DnsHelper }.new }
    let(:deployment_manifest_migrator) { instance_double(ManifestMigrator) }
    let(:planner_factory) {PlannerFactory.new(canonicalizer, deployment_manifest_migrator, deployment_repo, event_log, logger)}
    let(:deployment_repo) { DeploymentRepo.new(canonicalizer) }
    let(:event_log) {Bosh::Director::EventLog::Log.new(StringIO.new(''))}
    let(:cloud_config_model) { Bosh::Director::Models::CloudConfig.make(manifest: cloud_config_hash) }
    let(:planner) { planner_factory.create_from_manifest(manifest_hash, cloud_config_model, {}) }
    let(:job) { planner.jobs.first }
    let(:job_networks) { [{'name' => 'a', 'static_ips' => static_ips}] }
    before do
      allow(deployment_manifest_migrator).to receive(:migrate) { |deployment_manifest, cloud_config| [deployment_manifest, cloud_config.manifest] }
    end

    describe 'place_and_match' do
      context 'when the subnets and the jobs do not specify availability zones' do
        let(:static_ips) { ['192.168.1.10 - 192.168.1.12'] }

        before do
          cloud_config_hash['networks'].each do |entry|
            entry['subnets'].each { |subnet| subnet.delete('availability_zone') }
          end
          manifest_hash['jobs'].each { |entry| entry.delete('availability_zones') }
        end

        it 'does not assign AZs' do
          desired_instances = [new_desired_instance, new_desired_instance, new_desired_instance]
          existing_instances = []
          results = zone_picker.place_and_match_in(job.availability_zones, job.networks, desired_instances, existing_instances)

          expect(results[:desired_new].map(&:az)).to eq([nil, nil, nil])
        end
      end

      context 'when the job specifies a single network with all static IPs from a single AZ' do
        let(:static_ips) { ['192.168.1.10 - 192.168.1.12'] }

        it 'assigns instances to the AZs of the static ips' do
          desired_instances = [new_desired_instance, new_desired_instance, new_desired_instance]
          existing_instances = []
          results = zone_picker.place_and_match_in(job.availability_zones, job.networks, desired_instances, existing_instances)
          desired_new = results[:desired_new]

          expect(desired_new.count).to eq(3)
          expect(results[:desired_existing]).to eq([])
          expect(results[:obsolete]).to eq([])
          desired_new.each { |result| expect(result.az.name).to eq('zone1') }
        end
      end

      context 'when the job specifies a single network with static IPs spanning multiple AZs' do
        let(:static_ips) { ['192.168.1.10', '192.168.1.11', '192.168.2.10'] }

        it 'assigns instances to the AZs of the static ips' do
          desired_instances = [new_desired_instance, new_desired_instance, new_desired_instance]
          existing_instances = []
          results = zone_picker.place_and_match_in(job.availability_zones, job.networks, desired_instances, existing_instances)
          desired_new = results[:desired_new]

          expect(desired_new.count).to eq(3)
          expect(results[:desired_existing]).to eq([])
          expect(results[:obsolete]).to eq([])

          expect(desired_new[0].az.name).to eq('zone1')
          expect(desired_new[1].az.name).to eq('zone1')
          expect(desired_new[2].az.name).to eq('zone2')
        end
      end

      context 'when the job specifies multiple networks with static IPs from the same AZ' do
        let(:job_networks) do
          [
            {'name' => 'a', 'static_ips' => ['192.168.1.10', '192.168.1.11']},
            {'name' => 'b', 'static_ips' => ['10.10.1.10', '10.10.1.11']}
          ]
        end
      end

      context 'when there are existing instances' do
        context 'and the job is being migrated from a non-AZ legacy' do

        end

        context 'some of which have static IPs and AZ assignments' do

        end

        context 'some of which have static IPs, but no AZ assignments' do

        end

        context 'none of which have static IPs' do

        end
      end
    end

    def new_desired_instance
      DesiredInstance.new(job, 'started', planner)
    end

    def existing_instance_with_az(index, az, persistent_disks=[])
      instance_model = Bosh::Director::Models::Instance.make(index: index)
      allow(instance_model).to receive(:persistent_disks).and_return(persistent_disks)
      InstanceWithAZ.new(instance_model, az)
    end
  end
end
