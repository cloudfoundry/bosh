require 'spec_helper'

module Bosh
  module Director
    module DeploymentPlan
      describe PlannerFactory do
        subject { PlannerFactory.new(deployment_manifest_migrator, manifest_validator, deployment_repo, logger) }
        let(:deployment_repo) { DeploymentRepo.new }
        let(:deployment_name) { 'simple' }
        let(:manifest_hash) { Bosh::Spec::Deployments.simple_manifest }
        let(:deployment_manifest_migrator) { instance_double(ManifestMigrator) }
        let(:manifest_validator) { Bosh::Director::DeploymentPlan::ManifestValidator.new }
        let(:cloud_configs) { [Models::Config.make(:cloud, content: YAML.dump(cloud_config_hash))] }
        let(:runtime_config_models) { [instance_double(Bosh::Director::Models::Config)] }
        let(:runtime_config_consolidator) { instance_double(Bosh::Director::RuntimeConfig::RuntimeConfigsConsolidator) }
        let(:cloud_config_hash) { Bosh::Spec::Deployments.simple_cloud_config }
        let(:runtime_config_hash) { Bosh::Spec::Deployments.simple_runtime_config }
        let(:manifest_with_config_keys) { Bosh::Spec::Deployments.simple_manifest.merge('name' => 'with_keys') }
        let(:manifest) { Manifest.new(manifest_hash, YAML.dump(manifest_hash), cloud_config_hash, runtime_config_hash) }
        let(:plan_options) { {} }
        let(:event_log_io) { StringIO.new('') }
        let(:logger_io) { StringIO.new('') }
        let(:event_log) { Bosh::Director::EventLog::Log.new(event_log_io) }
        let(:logger) do
          logger = Logging::Logger.new('PlannerFactorySpecs')
          logger.add_appenders(
            Logging.appenders.io(
              'PlannerFactorySpecs IO',
              logger_io,
              layout: Logging.layouts.pattern(pattern: '%m\n')
            )
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
            let(:plan_options) { { 'canaries' => '10%', 'max_in_flight' => '3' } }
            it 'uses plan options' do
              deployment = planner
              expect(deployment.update.canaries_before_calculation).to eq('10%')
              expect(deployment.update.max_in_flight_before_calculation).to eq('3')
            end

            context 'when option value is incorrect' do
              let(:plan_options) { { 'canaries' => 'wrong' } }
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
              {"name"=>"migrated_name", "director_uuid"=>"deadbeef", "releases"=>[{"name"=>"bosh-release", "version"=>"0.1-dev"}], "update"=>{"canaries"=>2, "canary_watch_time"=>4000, "max_in_flight"=>1, "update_watch_time"=>20}, "jobs"=>[{"name"=>"foobar", "templates"=>[{"name"=>"foobar"}], "resource_pool"=>"a", "instances"=>3, "networks"=>[{"name"=>"a"}], "properties"=>{}}]}
LOGMESSAGE
            expected_cloud_manifest_log = <<~LOGMESSAGE
              Migrated cloud config manifest:
              {"networks"=>[{"name"=>"a", "subnets"=>[{"range"=>"192.168.1.0/24", "gateway"=>"192.168.1.1", "dns"=>["192.168.1.1", "192.168.1.2"], "static"=>["192.168.1.10"], "reserved"=>[], "cloud_properties"=>{}}]}], "compilation"=>{"workers"=>1, "network"=>"a", "cloud_properties"=>{}}, "resource_pools"=>[{"name"=>"a", "cloud_properties"=>{}, "stemcell"=>{"name"=>"ubuntu-stemcell", "version"=>"1"}, "env"=>{"bosh"=>{"password"=>"foobar"}}}]}
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
            let(:expected_attrs) { { name: 'simple', properties: {} } }
            let(:expected_plan_options) do
              { 'recreate' => false,
                'fix' => false,
                'skip_drain' => nil,
                'job_states' => {},
                'max_in_flight' => nil,
                'canaries' => nil,
                'tags' => {} }
            end

            before do
              allow(deployment_repo).to receive(:find_or_create_by_name).with(deployment_name, plan_options).and_return(deployment_model)
              allow(runtime_config_consolidator).to receive(:runtime_configs).and_return(runtime_config_models)
            end

            it 'calls planner new with appropriate arguments' do
              expect(Planner).to receive(:new).with(expected_attrs, manifest_hash,  YAML.dump(manifest_hash), cloud_configs, runtime_config_models, deployment_model, expected_plan_options).and_call_original
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
                    { 'name' => 'bosh-release', 'version' => 1 },
                    { 'name' => 'bar-release', 'version' => 2 }
                  ]
                )

                manifest_hash['jobs'].first['release'] = 'bosh-release'
                manifest_hash
              end

              before do
                allow(runtime_config_consolidator).to receive(:have_runtime_configs?).and_return(true)
                allow(runtime_config_consolidator).to receive(:interpolate_manifest_for_deployment).with('simple').and_return(runtime_config_hash)
              end

              it 'has the releases from the deployment manifest and the addon' do
                expect(planner.releases.map { |r| [r.name, r.version] }).to match_array(
                  [
                    ['bosh-release', '1'],
                    ['bar-release', '2'],
                    %w[test_release_2 2]
                  ]
                )
              end

              context 'with runtime variables' do
                let(:runtime_config_hash) do
                  Bosh::Spec::Deployments.simple_runtime_config.merge(
                    'variables' => [{
                      'name' => '/dns_healthcheck_server_tlsX',
                      'type' => 'certificate',
                      'options' => { 'is_ca' => true, 'common_name' => 'health.bosh-dns', 'extended_key_usage' => ['server_auth'] }
                    },
                                    {
                                      'name' => '/dns_healthcheck_tls',
                                      'type' => 'certificate',
                                      'options' => { 'ca' => '/dns_healthcheck_server_tlsX' }

                                    },
                                    {
                                      'name' => '/dns_healthcheck_password',
                                      'type' => 'password'
                                    }]
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
                Bosh::Spec::Deployments.simple_cloud_config.merge(
                  'disk_pools' => [
                    { 'name' => 'disk_pool1', 'disk_size' => 3000 },
                    { 'name' => 'disk_pool2', 'disk_size' => 1000 }
                  ]
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
                  'azs' => [
                    { 'name' => 'zone1', 'cloud_properties' => { foo: 'bar' } },
                    { 'name' => 'zone2', 'cloud_properties' => { foo: 'baz' } }
                  ]
                )
                hash['compilation']['az'] = 'zone1'

                first_subnet = hash['networks'][0]['subnets']
                first_subnet << Bosh::Spec::Deployments.subnet(
                  'range' => '192.168.2.0/24',
                  'gateway' => '192.168.2.1',
                  'dns' => ['192.168.2.1', '192.168.2.2'],
                  'static' => ['192.168.2.10'],
                  'reserved' => [],
                  'cloud_properties' => {}
                )

                hash['networks'].first['subnets'][0]['az'] = 'zone1'
                hash['networks'].first['subnets'][1]['az'] = 'zone2'
                hash
              end

              let(:manifest_hash) do
                Bosh::Spec::Deployments.simple_manifest.merge(
                  'jobs' => [
                    Bosh::Spec::Deployments.simple_job.merge('azs' => %w[zone1 zone2])
                  ]
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
                  Bosh::Spec::Deployments.simple_manifest.merge(
                    'jobs' => [
                      Bosh::Spec::Deployments.simple_job.merge('azs' => ['zone1']),
                      Bosh::Spec::Deployments.simple_job(name: 'bar').merge('azs' => ['zone2'])
                    ]
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

          describe 'links' do
            context 'when a job consumes a link' do
              before do
                manifest_hash.merge!(
                  'jobs' => [
                    { 'name' => 'job1-name',
                      'templates' => [{
                        'name' => 'provides_template',
                        'consumes' => {
                          'link_name' => { 'from' => 'link_name' }
                        }
                      }] }
                  ]
                )
              end

              let(:deployment_name) { 'deployment_name' }

              let(:job1) do
                job = Bosh::Director::DeploymentPlan::Job.new(release, 'provides_template', deployment_name)
                job.add_link_from_release('job1-name', 'consumes', 'link_name', 'name' => 'link_name', 'type' => 'link_type')
                job.add_link_from_release('job1-name', 'provides', 'link_name_2', 'properties' => ['a'])
                job
              end

              let(:instance_group1) do
                instance_double('Bosh::Director::DeploymentPlan::InstanceGroup',
                                name: 'job1-name',
                                canonical_name: 'job1-canonical-name',
                                jobs: [job1])
              end

              let(:link_path) do
                instance_double(
                  'Bosh::Director::DeploymentPlan::LinkPath',
                  deployment: 'deployment_name',
                  job: 'job_name',
                  template: 'provides_template',
                  name: 'link_name',
                  path: 'deployment_name.job_name.provides_template.link_name',
                  skip: false
                )
              end

              let(:skipped_link_path) do
                instance_double(
                  'Bosh::Director::DeploymentPlan::LinkPath',
                  deployment: 'deployment_name',
                  job: 'job_name',
                  template: 'provides_template',
                  name: 'link_name',
                  path: 'deployment_name.job_name.provides_template.link_name',
                  skip: true
                )
              end

              let(:release) do
                instance_double(
                  'Bosh::Director::DeploymentPlan::ReleaseVersion',
                  name: 'bosh-release'
                )
              end

              it 'should have a link_path' do
                allow(DeploymentPlan::InstanceGroup).to receive(:parse).and_return(instance_group1)
                expect(DeploymentPlan::LinkPath).to receive(:new).and_return(link_path)
                expect(link_path).to receive(:parse)
                expect(instance_group1).to receive(:add_link_path).with('provides_template', 'link_name', link_path)

                planner
              end

              it 'should not add a link path if no links found for optional ones, and it should not fail' do
                allow(DeploymentPlan::InstanceGroup).to receive(:parse).and_return(instance_group1)
                allow(job1).to receive(:release).and_return(release)
                allow(job1).to receive(:properties).and_return({})
                expect(DeploymentPlan::LinkPath).to receive(:new).and_return(skipped_link_path)
                expect(skipped_link_path).to receive(:parse)
                expect(instance_group1).to_not receive(:add_link_path)
                planner
              end

              context 'when template properties_json has the value "null"' do
                it 'should not throw an error' do
                  allow(DeploymentPlan::InstanceGroup).to receive(:parse).and_return(instance_group1)
                  allow(job1).to receive(:release).and_return(release)
                  allow(job1).to receive(:properties).and_return({})
                  allow(DeploymentPlan::LinkPath).to receive(:new).and_return(skipped_link_path)
                  allow(skipped_link_path).to receive(:parse)

                  templateModel = Models::Template.where(name: 'provides_template').first
                  templateModel.properties_json = 'null'
                  templateModel.save

                  expect(subject).to_not receive(:process_link_properties).with({}, { 'properties' => nil, 'template_name' => 'provides_template' }, ['a'], [])
                  planner
                end
              end

              context 'when link property has no default value and no value is set in the deployment manifest' do
                it 'should not throw an error' do
                  allow(DeploymentPlan::InstanceGroup).to receive(:parse).and_return(instance_group1)
                  allow(job1).to receive(:release).and_return(release)
                  allow(job1).to receive(:properties).and_return({})
                  allow(DeploymentPlan::LinkPath).to receive(:new).and_return(skipped_link_path)
                  allow(skipped_link_path).to receive(:parse)

                  template_model = Models::Template.where(name: 'provides_template').first
                  template_model.spec = template_model.spec.merge(properties: { 'a' => {} })
                  template_model.save

                  planner
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
            job = manifest_hash['jobs'].first
            release = Models::Release.make(name: release_entry['name'])
            template = Models::Template.make(name: job['templates'].first['name'], release: release)
            template2 = Models::Template.make(name: 'provides_template', release: release, spec: { properties: { 'a' => { default: 'b' } } })
            release_version = Models::ReleaseVersion.make(release: release, version: release_entry['version'])
            release_version.add_template(template)
            release_version.add_template(template2)
          end

          runtime_config_hash['releases'].each do |release_entry|
            release = Models::Release.make(name: release_entry['name'])
            Models::ReleaseVersion.make(release: release, version: release_entry['version'])
          end
        end

        def upload_stemcell
          stemcell_entry = cloud_config_hash['resource_pools'].first['stemcell']
          Models::Stemcell.make(name: stemcell_entry['name'], version: stemcell_entry['version'])
        end
      end
    end
  end
end
