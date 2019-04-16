require 'spec_helper'

module Bosh
  module Director
    module DeploymentPlan
      describe PlannerFactory do
        subject { PlannerFactory.new(deployment_manifest_migrator, manifest_validator, deployment_repo, logger) }
        let(:deployment_repo) { DeploymentRepo.new }
        let(:deployment_name) { 'simple' }
        let(:manifest_hash) { Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups }
        let(:deployment_manifest_migrator) { instance_double(ManifestMigrator) }
        let(:manifest_validator) { Bosh::Director::DeploymentPlan::ManifestValidator.new }
        let(:cloud_configs) { [Models::Config.make(:cloud, content: YAML.dump(cloud_config_hash))] }
        let(:runtime_config_models) { [instance_double(Bosh::Director::Models::Config)] }
        let(:runtime_config_consolidator) { instance_double(Bosh::Director::RuntimeConfig::RuntimeConfigsConsolidator) }
        let(:cloud_config_hash) { Bosh::Spec::NewDeployments.simple_cloud_config }
        let(:runtime_config_hash) { Bosh::Spec::Deployments.simple_runtime_config }
        let(:manifest_with_config_keys) { Bosh::Spec::Deployments.simple_manifest.merge('name' => 'with_keys') }
        let(:manifest) { Manifest.new(manifest_hash, YAML.dump(manifest_hash), cloud_config_hash, runtime_config_hash) }
        let(:plan_options) do
          {}
        end
        let(:event_log_io) { StringIO.new('') }
        let(:logger_io) { StringIO.new('') }
        let(:event_log) { Bosh::Director::EventLog::Log.new(event_log_io) }
        let(:logger) do
          logger = Logging::Logger.new('PlannerFactorySpecs')
          logger.add_appenders(
            Logging.appenders.io(
              'PlannerFactorySpecs IO',
              logger_io,
              layout: Logging.layouts.pattern(pattern: '%m\n'),
            ),
          )
          logger
        end

        before do
          allow(deployment_manifest_migrator).to receive(:migrate) { |deployment_manifest, cloud_config| [deployment_manifest, cloud_config] }
          allow(Bosh::Director::RuntimeConfig::RuntimeConfigsConsolidator).to receive(:new).with(runtime_config_models).and_return(runtime_config_consolidator)
          allow(runtime_config_consolidator).to receive(:interpolate_manifest_for_deployment).with('simple').and_return({})
          allow(runtime_config_consolidator).to receive(:tags).and_return({})
          allow(runtime_config_consolidator).to receive(:have_runtime_configs?).and_return(false)
          allow(runtime_config_consolidator).to receive(:runtime_configs)
          upload_releases
          upload_stemcell
          configure_config
          fake_locks
        end

        describe '#create_from_manifest' do
          let(:planner) do
            subject.create_from_manifest(manifest, cloud_configs, runtime_config_models, plan_options)
          end

          it 'returns a planner' do
            expect(planner).to be_a(Planner)
            expect(planner.name).to eq('simple')
          end

          it 'migrates the deployment manifest to handle legacy structure' do
            allow(deployment_manifest_migrator).to receive(:migrate) do |manifest, cloud_config|
              manifest.manifest_hash['name'] = 'migrated_name'
              [manifest, cloud_config]
            end

            expect(planner.name).to eq('migrated_name')
          end

          it 'resolves aliases in manifest' do
            manifest_hash['releases'].first['version'] = 'latest'
            planner
            expect(manifest_hash['releases'].first['version']).to eq('0.1-dev')
          end

          context 'plan_options' do
            let(:plan_options) do
              { 'canaries' => '10%', 'max_in_flight' => '3' }
            end
            it 'uses plan options' do
              deployment = planner
              expect(deployment.update.canaries_before_calculation).to eq('10%')
              expect(deployment.update.max_in_flight_before_calculation).to eq('3')
            end

            context 'when option value is incorrect' do
              let(:plan_options) do
                { 'canaries' => 'wrong' }
              end
              it 'raises an error' do
                expect { planner }.to raise_error 'canaries value should be integer or percent'
              end
            end
          end

          it 'logs the migrated manifests' do
            allow(deployment_manifest_migrator).to receive(:migrate) do |manifest, cloud_config|
              manifest.manifest_hash['name'] = 'migrated_name'
              [manifest, cloud_config]
            end

            planner
            expected_deployment_manifest_log = <<~LOGMESSAGE
              Migrated deployment manifest:
              {"name"=>"migrated_name", "director_uuid"=>"deadbeef", "releases"=>[{"name"=>"bosh-release", "version"=>"0.1-dev"}], "stemcells"=>[{"name"=>"ubuntu-stemcell", "version"=>"1", "alias"=>"default"}], "update"=>{"canaries"=>2, "canary_watch_time"=>4000, "max_in_flight"=>1, "update_watch_time"=>20}, "instance_groups"=>[{"name"=>"foobar", "stemcell"=>"default", "vm_type"=>"a", "instances"=>3, "networks"=>[{"name"=>"a"}], "properties"=>{}, "jobs"=>[{"name"=>"foobar", "properties"=>{}}]}]}
            LOGMESSAGE
            expected_cloud_manifest_log = <<~LOGMESSAGE
              Migrated cloud config manifest:
              {"networks"=>[{"name"=>"a", "subnets"=>[{"range"=>"192.168.1.0/24", "gateway"=>"192.168.1.1", "dns"=>["192.168.1.1", "192.168.1.2"], "static"=>["192.168.1.10"], "reserved"=>[], "cloud_properties"=>{}}]}], "compilation"=>{"workers"=>1, "network"=>"a", "cloud_properties"=>{}}, "vm_types"=>[{"name"=>"a", "cloud_properties"=>{}}]}
            LOGMESSAGE
            expect(logger_io.string).to include(expected_deployment_manifest_log)
            expect(logger_io.string).to include(expected_cloud_manifest_log)
          end

          it 'raises error when manifest has cloud_config properties' do
            manifest_hash['vm_types'] = 'foo'
            expect do
              subject.create_from_manifest(manifest, cloud_configs, runtime_config_models, plan_options)
            end.to raise_error(Bosh::Director::DeploymentInvalidProperty)
          end

          context 'Planner.new' do
            let(:deployment_model) { Models::Deployment.make(name: 'simple') }
            let(:expected_attrs) do
              { name: 'simple', properties: {} }
            end
            let(:expected_plan_options) do
              {
                'is_deploy_action' => false,
                'recreate' => false,
                'recreate_persistent_disks' => false,
                'fix' => false,
                'skip_drain' => nil,
                'job_states' => {},
                'max_in_flight' => nil,
                'canaries' => nil,
                'tags' => {},
              }
            end

            before do
              allow(deployment_repo).to receive(:find_or_create_by_name).with(deployment_name, plan_options).and_return(deployment_model)
              allow(runtime_config_consolidator).to receive(:runtime_configs).and_return(runtime_config_models)
            end

            it 'calls planner new with appropriate arguments' do
              expect(Planner).to receive(:new).with(expected_attrs, manifest_hash, YAML.dump(manifest_hash), cloud_configs, runtime_config_models, deployment_model, expected_plan_options).and_call_original
              planner
            end
          end

          describe 'attributes of the planner' do
            it 'has a backing model' do
              expect(planner.model.name).to eq('simple')
            end

            describe 'tags' do
              before do
                allow(runtime_config_consolidator).to receive(:tags).and_return('runtime_tag' => 'dryer')
              end

              it 'sets tag values from manifest and from runtime_config' do
                manifest_hash['tags'] = { 'deployment_tag' => 'sears' }
                runtime_config_hash['tags'] = { 'runtime_tag' => 'dryer' }

                expect(planner.tags).to eq('deployment_tag' => 'sears', 'runtime_tag' => 'dryer')
              end

              it 'passes deployment name to get interpolated runtime_config tags' do
                runtime_config_hash['tags'] = { 'runtime_tag' => '((some_variable))' }

                expect(runtime_config_consolidator).to receive(:tags).with('simple').and_return('runtime_tag' => 'some_interpolated_value')
                expect(planner.tags).to eq('runtime_tag' => 'some_interpolated_value')
              end

              it 'gives deployment manifest tags precedence over runtime_config tags' do
                manifest_hash['tags'] = { 'tag_key' => 'sears' }
                allow(runtime_config_consolidator).to receive(:tags).and_return('tag_key' => 'dryer')

                expect(planner.tags).to eq('tag_key' => 'sears')
              end
            end

            describe 'properties' do
              it 'comes from the deployment_manifest' do
                expected = {
                  'foo' => 1,
                  'bar' => { 'baz' => 2 },
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
                manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups.merge(
                  'releases' => [
                    { 'name' => 'bosh-release', 'version' => 1 },
                    { 'name' => 'bar-release', 'version' => 2 },
                  ],
                )

                manifest_hash['instance_groups'].first['jobs'].first['release'] = 'bosh-release'
                manifest_hash
              end

              before do
                allow(runtime_config_consolidator).to receive(:have_runtime_configs?).and_return(true)
                allow(runtime_config_consolidator).to receive(:interpolate_manifest_for_deployment).with('simple').and_return(runtime_config_hash)
              end

              context 'and the runtime config does not have any applicable jobs' do
                it 'has the releases from the deployment manifest' do
                  expect(planner.releases.map { |r| [r.name, r.version] }).to match_array(
                    [
                      ['bosh-release', '1'],
                      ['bar-release', '2'],
                    ],
                  )
                end
              end

              context 'and the runtime config does has applicable jobs' do
                let(:runtime_config_hash) do
                  Bosh::Spec::Deployments.simple_runtime_config.merge(
                    'addons' => [
                      {
                        'name' => 'first_addon',
                        'jobs' => [
                          { 'name' => 'my_template', 'release' => 'test_release_2' },
                        ],
                      },
                    ],
                  )
                end

                it 'has the releases from the deployment manifest and relevant addon releases' do
                  expect(planner.releases.map { |r| [r.name, r.version] }).to match_array(
                    [
                      %w[bosh-release 1],
                      %w[bar-release 2],
                      %w[test_release_2 2],
                    ],
                  )
                end
              end

              context 'with runtime variables' do
                let(:runtime_config_hash) do
                  Bosh::Spec::Deployments.simple_runtime_config.merge(
                    'variables' => [{
                      'name' => '/dns_healthcheck_server_tlsX',
                      'type' => 'certificate',
                      'options' => { 'is_ca' => true, 'common_name' => 'health.bosh-dns', 'extended_key_usage' => ['server_auth'] },
                    },
                                    {
                                      'name' => '/dns_healthcheck_tls',
                                      'type' => 'certificate',
                                      'options' => { 'ca' => '/dns_healthcheck_server_tlsX' },

                                    },
                                    {
                                      'name' => '/dns_healthcheck_password',
                                      'type' => 'password',
                                    }],
                  )
                end
                it 'has variables from runtime config' do
                  expect(planner.variables.spec[0]).to eq(runtime_config_hash['variables'][0])
                  expect(planner.variables.spec[1]).to eq(runtime_config_hash['variables'][1])
                  expect(planner.variables.spec[2]).to eq(runtime_config_hash['variables'][2])
                end
              end
            end

            describe 'disk_pools' do
              let(:cloud_config_hash) do
                Bosh::Spec::NewDeployments.simple_cloud_config.merge(
                  'disk_pools' => [
                    { 'name' => 'disk_pool1', 'disk_size' => 3000 },
                    { 'name' => 'disk_pool2', 'disk_size' => 1000 },
                  ],
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
                hash = Bosh::Spec::NewDeployments.simple_cloud_config.merge(
                  'azs' => [
                    { 'name' => 'zone1', 'cloud_properties' => { foo: 'bar' } },
                    { 'name' => 'zone2', 'cloud_properties' => { foo: 'baz' } },
                  ],
                )
                hash['compilation']['az'] = 'zone1'

                first_subnet = hash['networks'][0]['subnets']
                first_subnet << Bosh::Spec::NewDeployments.subnet(
                  'range' => '192.168.2.0/24',
                  'gateway' => '192.168.2.1',
                  'dns' => ['192.168.2.1', '192.168.2.2'],
                  'static' => ['192.168.2.10'],
                  'reserved' => [],
                  'cloud_properties' => {},
                )

                hash['networks'].first['subnets'][0]['az'] = 'zone1'
                hash['networks'].first['subnets'][1]['az'] = 'zone2'
                hash
              end

              let(:manifest_hash) do
                Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups.merge(
                  'instance_groups' => [
                    Bosh::Spec::NewDeployments.simple_instance_group.merge('azs' => %w[zone1 zone2]),
                  ],
                )
              end

              context 'when there is one job with two availability zones' do
                it 'has azs as specified by users' do
                  expect(planner.instance_groups.length).to eq(1)
                  expect(planner.instance_groups.first.availability_zones.map(&:name)).to eq(%w[zone1 zone2])
                  expect(planner.instance_groups.first.availability_zones.map(&:cloud_properties)).to eq([{ foo: 'bar' }, { foo: 'baz' }])
                end
              end

              context 'when there are two jobs with two availability zones' do
                let(:manifest_hash) do
                  Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups.merge(
                    'instance_groups' => [
                      Bosh::Spec::NewDeployments.simple_instance_group.merge('azs' => ['zone1']),
                      Bosh::Spec::NewDeployments.simple_instance_group(name: 'bar').merge('azs' => ['zone2']),
                    ],
                  )
                end
                it 'has azs as specified by users' do
                  expect(planner.instance_groups.length).to eq(2)
                  expect(planner.instance_groups[0].availability_zones.map(&:name)).to eq(['zone1'])
                  expect(planner.instance_groups[0].availability_zones.map(&:cloud_properties)).to eq([{ foo: 'bar' }])

                  expect(planner.instance_groups.length).to eq(2)
                  expect(planner.instance_groups[1].availability_zones.map(&:name)).to eq(['zone2'])
                  expect(planner.instance_groups[1].availability_zones.map(&:cloud_properties)).to eq([{ foo: 'baz' }])
                end
              end
            end
          end

          context 'runtime config' do
            before do
              allow(runtime_config_consolidator).to receive(:have_runtime_configs?).and_return(true)
            end

            it "throws an error if the version of a release is 'latest'" do
              invalid_manifest = Bosh::Spec::Deployments.runtime_config_latest_release
              allow(runtime_config_consolidator).to receive(:interpolate_manifest_for_deployment).with(String).and_return(invalid_manifest)

              expect do
                planner
              end.to raise_error Bosh::Director::RuntimeInvalidReleaseVersion,
                                 "Runtime manifest contains the release 'bosh-release' with version as 'latest'. " \
                                 'Please specify the actual version string.'
            end

            it 'throws an error if the release used by an addon is not listed in the releases section' do
              invalid_manifest = Bosh::Spec::Deployments.runtime_config_release_missing
              allow(runtime_config_consolidator).to receive(:interpolate_manifest_for_deployment).with(String).and_return(invalid_manifest)

              expect do
                planner
              end.to raise_error Bosh::Director::AddonReleaseNotListedInReleases,
                                 "Manifest specifies job 'job_using_pkg_2' which is defined in 'release2', " \
                                 "but 'release2' is not listed in the runtime releases section."
            end
          end
        end

        def configure_config
          allow(Config).to receive(:dns).and_return('address' => 'foo')
          Bosh::Director::Config.current_job = Bosh::Director::Jobs::BaseJob.new
          Bosh::Director::Config.current_job.task_id = 'fake-task-id'
        end

        def upload_releases
          manifest_hash['releases'].each do |release_entry|
            instance_group = manifest_hash['instance_groups'].first
            release = Models::Release.make(name: release_entry['name'])
            job = Models::Template.make(name: instance_group['jobs'].first['name'], release: release)
            job2 = Models::Template.make(name: 'provides_job', release: release, spec: { properties: { 'a' => { default: 'b' } } })
            release_version = Models::ReleaseVersion.make(release: release, version: release_entry['version'])
            release_version.add_template(job)
            release_version.add_template(job2)
          end

          runtime_config_hash['releases'].each do |release_entry|
            release = Models::Release.make(name: release_entry['name'])
            template = Models::Template.make(name: 'my_template', release: release)
            release_version = Models::ReleaseVersion.make(release: release, version: release_entry['version'])
            release_version.add_template(template)
          end
        end

        def upload_stemcell
          stemcell_entry = manifest_hash['stemcells'].first
          Models::Stemcell.make(name: stemcell_entry['name'], version: stemcell_entry['version'])
        end
      end
    end
  end
end
