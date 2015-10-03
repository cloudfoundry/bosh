require 'spec_helper'

module Bosh
  module Director
    module DeploymentPlan
      describe PlannerFactory do
        subject { PlannerFactory.new(canonicalizer, deployment_manifest_migrator, deployment_repo, event_log, logger) }
        let(:deployment_repo) { DeploymentRepo.new(canonicalizer) }
        let(:canonicalizer) { Class.new { include Bosh::Director::DnsHelper }.new }
        let(:manifest_hash) { Bosh::Spec::Deployments.simple_manifest }
        let(:deployment_manifest_migrator) { instance_double(ManifestMigrator) }
        let(:cloud_config_model) { Models::CloudConfig.make(manifest: cloud_config_hash) }
        let(:cloud_config_hash) { Bosh::Spec::Deployments.simple_cloud_config }
        let(:plan_options) { {} }
        let(:event_log_io) { StringIO.new("") }
        let(:logger_io) { StringIO.new("") }
        let(:event_log) {Bosh::Director::EventLog::Log.new(event_log_io)}
        let(:logger) do
          logger = Logging::Logger.new('PlannerFactorySpecs')
          logger.add_appenders(
            Logging.appenders.io(
              'PlannerFactorySpecs IO',
              logger_io,
              layout: Logging.layouts.pattern(:pattern => '%m\n')
            )
          )
          logger
        end

        before do
          allow(deployment_manifest_migrator).to receive(:migrate) { |deployment_manifest, cloud_config| [deployment_manifest, cloud_config.manifest] }
          upload_releases
          upload_stemcell
          configure_config
          fake_locks
        end

        describe '#create_from_manifest' do
          let(:planner) do
            subject.create_from_manifest(manifest_hash, cloud_config_model, plan_options)
          end

          it 'returns a planner' do
            expect(planner).to be_a(Planner)
            expect(planner.name).to eq('simple')
          end

          it 'migrates the deployment manifest to handle legacy structure' do
            allow(deployment_manifest_migrator).to receive(:migrate) do |hash, cloud_config|
              [hash.merge({'name' => 'migrated_name'}), cloud_config.manifest]
            end

            expect(planner.name).to eq('migrated_name')
          end

          it 'logs the migrated manifests' do
            allow(deployment_manifest_migrator).to receive(:migrate) do |hash, cloud_config|
              [hash.merge({'name' => 'migrated_name'}), cloud_config.manifest]
            end

            planner
# rubocop:disable LineLength
            expected_deployment_manifest_log = <<LOGMESSAGE
Migrated deployment manifest:
{"name"=>"migrated_name", "director_uuid"=>"deadbeef", "releases"=>[{"name"=>"bosh-release", "version"=>"0.1-dev"}], "update"=>{"canaries"=>2, "canary_watch_time"=>4000, "max_in_flight"=>1, "update_watch_time"=>20}, "jobs"=>[{"name"=>"foobar", "templates"=>[{"name"=>"foobar"}], "resource_pool"=>"a", "instances"=>3, "networks"=>[{"name"=>"a"}], "properties"=>{}}]}
LOGMESSAGE
            expected_cloud_manifest_log = <<LOGMESSAGE
Migrated cloud config manifest:
{"networks"=>[{"name"=>"a", "subnets"=>[{"range"=>"192.168.1.0/24", "gateway"=>"192.168.1.1", "dns"=>["192.168.1.1", "192.168.1.2"], "static"=>["192.168.1.10"], "reserved"=>[], "cloud_properties"=>{}}]}], "compilation"=>{"workers"=>1, "network"=>"a", "cloud_properties"=>{}}, "resource_pools"=>[{"name"=>"a", "size"=>3, "cloud_properties"=>{}, "stemcell"=>{"name"=>"ubuntu-stemcell", "version"=>"1"}}]}
LOGMESSAGE
# rubocop:enable LineLength
            expect(logger_io.string).to include(expected_deployment_manifest_log)
            expect(logger_io.string).to include(expected_cloud_manifest_log)
          end

          describe 'attributes of the planner' do
            it 'has a backing model' do
              expect(planner.model.name).to eq('simple')
            end

            describe 'properties' do
              it 'comes from the deployment_manifest' do
                expected = {
                  'foo' => 1,
                  'bar' => { 'baz' => 2 }
                }
                manifest_hash['properties'] = expected
                expect(planner.properties).to eq(expected)
              end

              it 'has a sensible default' do
                manifest_hash.delete('properties')
                expect(planner.properties).to eq({})
              end
            end

            describe 'releases' do
              let(:manifest_hash) do
                manifest_hash = Bosh::Spec::Deployments.simple_manifest.merge(
                  'releases' => [
                    {'name' => 'bosh-release', 'version' => 1},
                    {'name' => 'bar-release', 'version' => 2},
                  ],
                )

                manifest_hash['jobs'].first['release'] = 'bosh-release'
                manifest_hash
              end

              it 'has the releases from the deployment manifest' do
                expect(planner.releases.map { |r| [r.name, r.version] }).to match_array(
                  [
                    ['bosh-release', '1'],
                    ['bar-release', '2']
                  ]
                )
              end
            end

            describe 'disk_pools' do
              let(:cloud_config_hash) do
                Bosh::Spec::Deployments.simple_cloud_config.merge(
                  {
                    'disk_pools' => [
                      {'name' => 'disk_pool1', 'disk_size' => 3000},
                      {'name' => 'disk_pool2', 'disk_size' => 1000},
                    ]
                  }
                )
              end

              it 'has disk_pools from the cloud config manifest' do
                expect(planner.disk_types.length).to eq(2)
                expect(planner.disk_type('disk_pool1').disk_size).to eq(3000)
                expect(planner.disk_type('disk_pool2').disk_size).to eq(1000)
              end
            end

            describe 'jobs' do
              let(:cloud_config_hash) do
                hash = Bosh::Spec::Deployments.simple_cloud_config.merge(
                  'availability_zones' => [
                    {'name' => 'zone1', 'cloud_properties' => {foo: 'bar'}},
                    {'name' => 'zone2', 'cloud_properties' => {foo: 'baz'}},
                  ]
                )
                hash['networks'].first['subnets'] << Bosh::Spec::Deployments.subnet({
                    'range' => '192.168.2.0/24',
                    'gateway' => '192.168.2.1',
                    'dns' => ['192.168.2.1', '192.168.2.2'],
                    'static' => ['192.168.2.10'],
                    'reserved' => [],
                    'cloud_properties' => {},
                  })

                hash['networks'].first['subnets'][0]['availability_zone'] = 'zone1'
                hash['networks'].first['subnets'][1]['availability_zone'] = 'zone2'
                hash
              end
              let(:manifest_hash) do
                Bosh::Spec::Deployments.simple_manifest.merge(
                  'jobs' => [
                    Bosh::Spec::Deployments.simple_job().merge('availability_zones' => ['zone1', 'zone2'])
                  ]
                )
              end

              context 'when there is one job with two availability zones' do
                it 'has availability_zones as specified by users' do
                  expect(planner.jobs.length).to eq(1)
                  expect(planner.jobs.first.availability_zones.map(&:name)).to eq(['zone1', 'zone2'])
                  expect(planner.jobs.first.availability_zones.map(&:cloud_properties)).to eq([{foo: 'bar'}, {foo: 'baz'}])
                end
              end

              context 'when there are two jobs with two availability zones' do
                let(:manifest_hash) do
                  Bosh::Spec::Deployments.simple_manifest.merge(
                    'jobs' => [
                      Bosh::Spec::Deployments.simple_job().merge('availability_zones' => ['zone1']),
                      Bosh::Spec::Deployments.simple_job(name:'bar').merge('availability_zones' => ['zone2'])
                    ]
                  )
                end
                it 'has availability_zones as specified by users' do
                  expect(planner.jobs.length).to eq(2)
                  expect(planner.jobs[0].availability_zones.map(&:name)).to eq(['zone1'])
                  expect(planner.jobs[0].availability_zones.map(&:cloud_properties)).to eq([{foo: 'bar'}])

                  expect(planner.jobs.length).to eq(2)
                  expect(planner.jobs[1].availability_zones.map(&:name)).to eq(['zone2'])
                  expect(planner.jobs[1].availability_zones.map(&:cloud_properties)).to eq([{foo: 'baz'}])
                end
              end
            end
          end
        end

        def configure_config
          allow(Config).to receive(:dns_domain_name).and_return('some-dns-domain-name')
          allow(Config).to receive(:dns).and_return({'address' => 'foo'})
          allow(Config).to receive(:cloud).and_return(double('cloud'))
          Bosh::Director::Config.current_job = Bosh::Director::Jobs::BaseJob.new
          Bosh::Director::Config.current_job.task_id = 'fake-task-id'
        end

        def upload_releases
          manifest_hash['releases'].each do |release_entry|
            job = manifest_hash['jobs'].first
            release = Models::Release.make(name: release_entry['name'])
            template = Models::Template.make(name: job['templates'].first['name'], release: release)
            release_version = Models::ReleaseVersion.make(release: release, version: release_entry['version'])
            release_version.add_template(template)
          end
        end

        def upload_stemcell
          stemcell_entry = cloud_config_model.manifest['resource_pools'].first['stemcell']
          Models::Stemcell.make(name: stemcell_entry['name'], version: stemcell_entry['version'])
        end
      end
    end
  end
end
