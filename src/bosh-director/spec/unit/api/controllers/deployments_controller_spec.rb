require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::DeploymentsController do
      include IpUtil
      include Rack::Test::Methods

      subject(:app) { linted_rack_app(described_class.new(config)) }

      let(:config) do
        config = Config.load_hash(SpecHelper.director_config_hash)
        identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
        allow(config).to receive(:identity_provider).and_return(identity_provider)
        config
      end

      def manifest_with_errand_hash(deployment_name='errand')
        manifest_hash = SharedSupport::DeploymentManifestHelper.manifest_with_errand
        manifest_hash['name'] = deployment_name
        manifest_hash['instance_groups'] << {
          'name' => 'another-errand',
          'jobs' => [{ 'name' => 'errand1', 'release' => 'bosh-release' }],
          'stemcell' => 'default',
          'lifecycle' => 'errand',
          'vm_type' => 'a',
          'instances' => 1,
          'networks' => [{ 'name' => 'a' }],
        }
        manifest_hash
      end

      def manifest_with_errand(deployment_name='errand')
        YAML.dump(manifest_with_errand_hash(deployment_name))
      end

      let(:cloud_config) { FactoryBot.create(:models_config_cloud, :with_manifest) }
      let(:time) { Time.now }

      before do
        App.new(config)
        basic_authorize 'admin', 'admin'
      end

      describe 'the date header' do
        it 'is present' do
          basic_authorize 'reader', 'reader'
          get '/'
          expect(last_response.headers['Date']).to be
        end
      end

      describe 'API calls' do
        describe 'creating a deployment' do
          context 'authenticated access' do
            it 'expects compressed deployment file' do
              post '/', asset_content('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml'}
              expect_redirect_to_queued_task(last_response)
            end

            it 'accepts a context ID header' do
              context_id = 'example-context-id'
              header('X-Bosh-Context-Id', context_id)
              post '/', asset_content('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml'}
              task = expect_redirect_to_queued_task(last_response)
              expect(task.context_id).to eq(context_id)
            end

            it 'defaults to no context ID' do
              post '/', asset_content('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml'}
              task = expect_redirect_to_queued_task(last_response)
              expect(task.context_id).to eq('')
            end

            it 'only consumes text/yaml' do
              post '/', asset_content('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/plain'}
              expect(last_response.status).to eq(404)
            end

            it 'gives a nice error when request body is not a valid yml' do
              post '/', "}}}i'm not really yaml, hah!", {'CONTENT_TYPE' => 'text/yaml'}

              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)['code']).to eq(440001)
              expect(JSON.parse(last_response.body)['description']).to include('Incorrect YAML structure of the uploaded manifest: ')
            end

            it 'gives a nice error when request body is empty' do
              post '/', '', {'CONTENT_TYPE' => 'text/yaml'}

              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)).to eq(
                'code' => 440001,
                'description' => 'Manifest should not be empty',
              )
            end

            it 'gives a nice error when deployment manifest does not have a name' do
              post '/', YAML.dump({}), {'CONTENT_TYPE' => 'text/yaml'}

              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)).to eq(
                'code' => 40001,
                'description' => "Deployment manifest must have a 'name' key",
              )
              end

            it 'gives a nice error when deployment manifest is not a Hash' do
              post '/', YAML.dump(true), {'CONTENT_TYPE' => 'text/yaml'}

              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)).to eq(
                'code' => 440001,
                'description' => 'Manifest should be a hash',
              )
            end

            context 'when provided cloud configs and runtime configs context to work within' do
              it 'should use the provided context instead of using the latest runtime and cloud config' do
                cloud_config = FactoryBot.create(:models_config_cloud, :with_manifest)
                runtime_config1 = FactoryBot.create(:models_config_runtime)
                runtime_config2 = FactoryBot.create(:models_config_runtime)

                FactoryBot.create(:models_config_cloud, :with_manifest)
                FactoryBot.create(:models_config, type: 'runtime')

                deployment_context = [[
                  'context',
                  JSON.dump(
                    'cloud_config_ids' => [cloud_config.id],
                    'runtime_config_ids' => [runtime_config1.id, runtime_config2.id],
                  ),
                ]]

                expect_any_instance_of(DeploymentManager)
                  .to receive(:create_deployment)
                  .with(
                    anything,
                    anything,
                    [cloud_config],
                    a_collection_containing_exactly(runtime_config1, runtime_config2),
                    anything,
                    anything,
                    anything,
                  ).and_return(FactoryBot.create(:models_task))

                post "/?#{URI.encode_www_form(deployment_context)}", asset_content('test_conf.yaml'), 'CONTENT_TYPE' => 'text/yaml'
                expect_redirect_to_queued_task(last_response)
              end

              context 'with an authorized team' do
                before { basic_authorize 'dev-team-member', 'dev-team-member' }

                let(:runtime_config_1) { FactoryBot.create(:models_config_runtime, raw_manifest: {'addons' => []}) }
                let(:runtime_config_2) { FactoryBot.create(:models_config_runtime, raw_manifest: {'addons' => []}) }
                let(:runtime_config_3) { FactoryBot.create(:models_config_runtime, raw_manifest: {'addons' => []}, name: 'smurf') }
                let(:cloud_config) { FactoryBot.create(:models_config_cloud, raw_manifest: {'azs' => []}) }

                let(:dev_team) { FactoryBot.create(:models_team, name: 'dev') }
                let(:other_team) { FactoryBot.create(:models_team, name: 'other') }

                let!(:dev_runtime_config) { FactoryBot.create(:models_config_runtime, name: 'dev-runtime', team_id: dev_team.id) }
                let!(:other_runtime_config) { FactoryBot.create(:models_config_runtime, name: 'other-runtime', team_id: other_team.id) }

                let!(:dev_cloud_config) { FactoryBot.create(:models_config_cloud, name: 'dev-cloud', team_id: dev_team.id) }
                let!(:other_cloud_config) { FactoryBot.create(:models_config_cloud, name: 'other-cloud', team_id: other_team.id) }

                it 'should error if the user references a cloud config from another team' do
                  deployment_context = [['context', JSON.dump({'cloud_config_ids' => [dev_cloud_config.id, other_cloud_config.id], 'runtime_config_ids' => []})]]

                  response = post "/?#{URI.encode_www_form(deployment_context)}", asset_content('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml'}
                  expect(response.status).to eq(400)
                  expect(response.body).to match(/Context includes invalid config ID/)
                end

                it 'should error if the user references a runtime config from another team' do
                  deployment_context = [['context', JSON.dump({'cloud_config_ids' => [], 'runtime_config_ids' => [dev_runtime_config.id, other_runtime_config.id]})]]

                  response = post "/?#{URI.encode_www_form(deployment_context)}", asset_content('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml'}
                  expect(response.status).to eq(400)
                  expect(response.body).to match(/Context includes invalid config ID/)
                end

                it 'should accept global and team-specific cloud and runtime configs' do
                  deployment_context = [['context', JSON.dump({'cloud_config_ids' => [cloud_config.id, dev_cloud_config.id], 'runtime_config_ids' => [runtime_config_3.id, dev_runtime_config.id]})]]

                  expect_any_instance_of(DeploymentManager)
                    .to receive(:create_deployment)
                          .with(
                            anything,
                            anything,
                            contain_exactly(cloud_config, dev_cloud_config),
                            contain_exactly(runtime_config_3, dev_runtime_config),
                            anything,
                            anything,
                            anything
                          )
                          .and_return(FactoryBot.create(:models_task))

                  response = post "/?#{URI.encode_www_form(deployment_context)}", asset_content('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml'}

                  expect(response.status).to eq(302)
                end
              end
            end

            context 'when using cloud config and runtime config' do
              it 'should persist these relations when persisting the deployment' do
                cloud_config = FactoryBot.create(:models_config_cloud, :with_manifest)
                runtime_config = FactoryBot.create(:models_config_runtime)

                post '/', asset_content('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml'}

                expect_redirect_to_queued_task(last_response)
                deployment = Models::Deployment.first
                expect(deployment.cloud_configs).to contain_exactly(cloud_config)
                expect(deployment.runtime_configs).to contain_exactly(runtime_config)
              end
            end

            context 'when doing a deploy with dry-run' do
              it 'should queue a dry run task' do
                expect(Models::Task.all).to be_empty

                post '/?dry_run=true', asset_content('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml'}

                expect_redirect_to_queued_task(last_response)

                expect(Models::Task.count).to eq(1)
                expect(Models::Task.first.description).to eq('create deployment (dry run)')
              end
            end

            context 'no existing context provided' do
              let(:runtime_config_1) { FactoryBot.create(:models_config_runtime, raw_manifest: {'addons' => []}) }
              let(:runtime_config_2) { FactoryBot.create(:models_config_runtime, raw_manifest: {'addons' => []}) }
              let(:runtime_config_3) { FactoryBot.create(:models_config_runtime, raw_manifest: {'addons' => []}, name: 'smurf') }
              let(:cloud_config) { FactoryBot.create(:models_config_cloud, raw_manifest: {'azs' => []}) }

              let(:dev_team) { FactoryBot.create(:models_team, name: 'dev') }
              let(:other_team) { FactoryBot.create(:models_team, name: 'other') }

              let!(:dev_runtime_config) { FactoryBot.create(:models_config_runtime, name: 'dev-runtime', team_id: dev_team.id) }
              let!(:other_runtime_config) { FactoryBot.create(:models_config_runtime, name: 'other-runtime', team_id: other_team.id) }

              let!(:dev_cloud_config) { FactoryBot.create(:models_config_cloud, name: 'dev-cloud', team_id: dev_team.id) }
              let!(:other_cloud_config) { FactoryBot.create(:models_config_cloud, name: 'other-cloud', team_id: other_team.id) }

              context 'with team-specific user' do
                before { basic_authorize 'dev-team-member', 'dev-team-member' }

                it 'filter cloud and runtime configs for team' do
                  expect_any_instance_of(DeploymentManager)
                    .to receive(:create_deployment)
                          .with(
                            anything,
                            anything,
                            a_collection_containing_exactly(dev_cloud_config, cloud_config),
                            a_collection_containing_exactly(dev_runtime_config, runtime_config_2, runtime_config_3),
                            anything,
                            anything,
                            anything
                          )
                          .and_return(FactoryBot.create(:models_task))

                  response = post '/', asset_content('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml'}

                  expect(response.status).to eq(302)
                end
              end

              context 'existing team deployment' do
                let!(:deployment) { FactoryBot.create(:models_deployment, name: 'deployment-name').tap { |d| d.teams = [dev_team] } }

                it 'uses the teams of the existing deployment' do
                  expect_any_instance_of(DeploymentManager)
                    .to receive(:create_deployment)
                          .with(
                            anything,
                            anything,
                            contain_exactly(dev_cloud_config, cloud_config),
                            contain_exactly(dev_runtime_config, runtime_config_2, runtime_config_3),
                            anything,
                            anything,
                            anything
                          )
                          .and_return(FactoryBot.create(:models_task))

                  response = post '/', asset_content('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml'}

                  expect(response.status).to eq(302)
                end
              end
            end
          end

          context 'accessing with invalid credentials' do
            before { authorize 'invalid-user', 'invalid-password' }

            it 'returns 401' do
              post '/', asset_content('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml'}
              expect(last_response.status).to eq(401)
            end
          end
        end

        describe 'updating a deployment' do
          let!(:deployment) { Models::Deployment.create(name: 'my-test-deployment', manifest: YAML.dump({ 'foo' => 'bar' })) }

          context 'without the "skip_drain" param' do
            it 'does not skip draining' do
              expect_any_instance_of(DeploymentManager)
                .to receive(:create_deployment)
                .with(anything, anything, anything, anything, anything, hash_excluding('skip_drain'), anything)
                .and_return(OpenStruct.new(id: 1))
              post '/', asset_content('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml' }
              expect(last_response).to be_redirect
            end
          end

          context 'with the "skip_drain" param as "*"' do
            it 'skips draining' do
              expect_any_instance_of(DeploymentManager)
                .to receive(:create_deployment)
                .with(anything, anything, anything, anything, anything, hash_including('skip_drain' => '*'), anything)
                .and_return(OpenStruct.new(id: 1))
              post '/?skip_drain=*', asset_content('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml' }
              expect(last_response).to be_redirect
            end
          end

          context 'with the "skip_drain" param as "job_one,job_two"' do
            it 'skips draining' do
              expect_any_instance_of(DeploymentManager)
                .to receive(:create_deployment)
                .with(anything, anything, anything, anything, anything, hash_including('skip_drain' => 'job_one,job_two'), anything)
                .and_return(OpenStruct.new(id: 1))
              post '/?skip_drain=job_one,job_two', asset_content('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml' }
              expect(last_response).to be_redirect
            end
          end

          context 'with the "fix" param' do
            it 'passes the parameter' do
              expect_any_instance_of(DeploymentManager)
                .to receive(:create_deployment)
                .with(anything, anything, anything, anything, anything, hash_including('fix' => true), anything)
                .and_return(OpenStruct.new(id: 1))
              post '/?fix=true', asset_content('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml'}
              expect(last_response).to be_redirect
            end
          end

          context 'with the "canaries" param' do
            it 'passes the parameter' do
              expect_any_instance_of(DeploymentManager)
                .to receive(:create_deployment)
                .with(anything, anything, anything, anything, anything, hash_including('canaries' => '1'), anything)
                .and_return(OpenStruct.new(id: 1))
              post '/?canaries=1', asset_content('test_conf.yaml'), 'CONTENT_TYPE' => 'text/yaml'
              expect(last_response).to be_redirect
            end
          end

          context 'with the "max-in-flight" param' do
            it 'passes the parameter' do
              expect_any_instance_of(DeploymentManager)
                .to receive(:create_deployment)
                .with(anything, anything, anything, anything, anything, hash_including('max_in_flight' => '1'), anything)
                .and_return(OpenStruct.new(id: 1))
              post '/?max_in_flight=1', asset_content('test_conf.yaml'), 'CONTENT_TYPE' => 'text/yaml'
              expect(last_response).to be_redirect
            end
          end

          context 'with the "recreate_persistent_disks" param' do
            it 'passes the parameter' do
              expect_any_instance_of(DeploymentManager)
                .to receive(:create_deployment)
                .with(
                  anything,
                  anything,
                  anything,
                  anything,
                  anything,
                  hash_including('recreate_persistent_disks' => true),
                  anything,
                ).and_return(OpenStruct.new(id: 1))
              post '/?recreate_persistent_disks=true', asset_content('test_conf.yaml'), 'CONTENT_TYPE' => 'text/yaml'
              expect(last_response).to be_redirect
            end
          end

          context 'updates using a manifest with deployment name' do
            it 'calls create deployment with deployment name' do
              expect_any_instance_of(DeploymentManager)
                  .to receive(:create_deployment)
                          .with(anything, anything, anything, anything, deployment, hash_excluding('skip_drain'), anything)
                          .and_return(OpenStruct.new(id: 1))
              post '/', asset_content('test_manifest.yml'), { 'CONTENT_TYPE' => 'text/yaml' }
              expect(last_response).to be_redirect
            end
          end

          context 'sets `new` option' do
            it 'to false' do
              expect_any_instance_of(DeploymentManager)
                  .to receive(:create_deployment)
                          .with(anything, anything, anything, anything, deployment, hash_including('new' => false), anything)
                          .and_return(OpenStruct.new(id: 1))
              post '/', asset_content('test_manifest.yml'), { 'CONTENT_TYPE' => 'text/yaml' }
            end

            it 'to true' do
              expect_any_instance_of(DeploymentManager)
                  .to receive(:create_deployment)
                          .with(anything, anything, anything, anything, anything, hash_including('new' => true), anything)
                          .and_return(OpenStruct.new(id: 1))
               Models::Deployment.first.delete
              post '/', asset_content('test_manifest.yml'), { 'CONTENT_TYPE' => 'text/yaml' }
            end
          end

          context 'with the "force_latest_variables" param which is needed because their BOSH DNS certs expire tomorrow and there is no new stemcell to trigger a cert rotation' do
            it 'passes the parameter' do
              expect_any_instance_of(DeploymentManager)
                .to receive(:create_deployment)
                      .with(anything, anything, anything, anything, anything, hash_including('force_latest_variables' => true), anything)
                      .and_return(OpenStruct.new(id: 1))
              post '/?force_latest_variables=true', asset_content('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml'}
              expect(last_response).to be_redirect
            end
          end
        end

        describe 'deleting deployment' do
          it 'deletes the deployment' do
            Models::Deployment.create(name: 'test_deployment', manifest: YAML.dump({ 'foo' => 'bar' }))

            delete '/test_deployment'
            expect_redirect_to_queued_task(last_response)
          end

          it 'accepts a context id' do
            context_id = 'example-context-id'
            Models::Deployment.create(name: 'test_deployment', manifest: YAML.dump({ 'foo' => 'bar' }))

            header('X-Bosh-Context-Id', context_id)
            delete '/test_deployment'

            task = expect_redirect_to_queued_task(last_response)
            expect(task.context_id).to eq(context_id)
          end
        end

        describe 'stopping an instance in isolation' do
          let!(:deployment) { Models::Deployment.create(name: 'test-deployment', manifest: YAML.dump('foo' => 'bar')) }
          let!(:instance) { FactoryBot.create(:models_instance, deployment: deployment, job: 'dea', index: '2') }

          context 'for a generic soft stop request' do
            let(:task) { instance_double('Bosh::Director::Models::Task', id: 1) }
            let(:job_queue) { instance_double('Bosh::Director::JobQueue', enqueue: task) }
            before { allow(JobQueue).to receive(:new).and_return(job_queue) }

            it 'enqueues a UpdateInstance task' do
              expect(job_queue).to receive(:enqueue).with(
                'admin',
                Jobs::UpdateInstance,
                'stop instance',
                ['test-deployment', instance.id, 'stop', { hard: false, skip_drain: false }],
                deployment,
                '',
              ).and_return(task)

              post '/test-deployment/instance_groups/dea/2/actions/stop'
              expect(last_response).to be_redirect
            end
          end

          context 'when skip_drain and hard stop are both requested' do
            let(:task) { instance_double('Bosh::Director::Models::Task', id: 1) }
            let(:job_queue) { instance_double('Bosh::Director::JobQueue', enqueue: task) }
            before { allow(JobQueue).to receive(:new).and_return(job_queue) }

            it 'enqueues a UpdateInstance task with the correct options' do
              expect(job_queue).to receive(:enqueue).with(
                'admin',
                Jobs::UpdateInstance,
                'stop instance',
                ['test-deployment', instance.id, 'stop', { hard: true, skip_drain: true }],
                deployment,
                '',
              ).and_return(task)

              post '/test-deployment/instance_groups/dea/2/actions/stop?skip_drain=true&hard=true'
              expect(last_response).to be_redirect
            end
          end
        end

        describe 'job management' do
          context 'when team-authorized' do
            before do
              basic_authorize 'dev-team-member', 'dev-team-member'
              FactoryBot.create(:models_config_runtime, name: 'other-runtime', team_id: other_team.id)
              FactoryBot.create(:models_config_cloud, name: 'other-cloud', team_id: other_team.id)
              Models::PersistentDisk.create(instance: instance, disk_cid: 'disk_cid')
            end

            let!(:runtime_config) { FactoryBot.create(:models_config_runtime, raw_manifest: {'addons' => []}) }
            let!(:cloud_config) { FactoryBot.create(:models_config_cloud, raw_manifest: {'azs' => []}) }

            let!(:dev_team) { FactoryBot.create(:models_team, name: 'dev') }
            let!(:dev_runtime_config) { FactoryBot.create(:models_config_runtime, name: 'dev-runtime', team_id: dev_team.id) }
            let!(:dev_cloud_config) { FactoryBot.create(:models_config_cloud, name: 'dev-cloud', team_id: dev_team.id) }
            let!(:other_team) { FactoryBot.create(:models_team, name: 'other') }

            let!(:deployment) do
              FactoryBot.create(:models_deployment, name: 'foo', manifest: YAML.dump({'foo' => 'bar'})).tap { |d| d.teams = [dev_team] }
            end

            let!(:instance) do
              FactoryBot.create(:models_instance,
                deployment: deployment,
                job: 'dea',
                index: '2',
                uuid: '0B949287-CDED-4761-9002-FC4035E11B21',
                state: 'started',
                variable_set: Models::VariableSet.create(deployment: deployment)
              )
            end

            it 'uses the correct configs when updating instance groups' do
              expect_any_instance_of(DeploymentManager).to receive(:create_deployment).
                with(
                  anything,
                  anything,
                  contain_exactly(cloud_config, dev_cloud_config),
                  contain_exactly(runtime_config, dev_runtime_config),
                  deployment,
                  anything,
                  anything,
                ).and_return(FactoryBot.create(:models_task))

              put '/foo/jobs/*?state=stopped', asset_content('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml' }
              expect_redirect_to_queued_task(last_response)
            end

            it 'uses the correct configs when updating an instance' do
              expect_any_instance_of(DeploymentManager).to receive(:create_deployment).
                with(
                  anything,
                  anything,
                  contain_exactly(cloud_config, dev_cloud_config),
                  contain_exactly(runtime_config, dev_runtime_config),
                  deployment,
                  anything,
                  anything,
                ).and_return(FactoryBot.create(:models_task))

              put '/foo/jobs/dea/0B949287-CDED-4761-9002-FC4035E11B21?state=stopped', asset_content('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml' }
              expect_redirect_to_queued_task(last_response)
            end
          end

          shared_examples 'change state' do
            it 'allows to change state' do
              deployment = Models::Deployment.create(name: 'foo', manifest: YAML.dump({'foo' => 'bar'}))
              instance = Models::Instance.create(
                deployment: deployment,
                job: 'dea',
                index: '2',
                uuid: '0B949287-CDED-4761-9002-FC4035E11B21',
                state: 'started',
                variable_set: Models::VariableSet.create(deployment: deployment)
              )
              Models::PersistentDisk.create(instance: instance, disk_cid: 'disk_cid')
              put "#{path}", asset_content('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml' }
              expect_redirect_to_queued_task(last_response)
            end

            it 'allows to change state with content_length of 0' do
              RSpec::Matchers.define :not_to_have_body do |unexpected|
                match { |actual| actual != unexpected }
              end
              manifest = asset_content('test_conf.yaml')
              expect_any_instance_of(DeploymentManager)
                .to receive(:create_deployment)
                .with(anything, not_to_have_body(manifest), anything, anything,
                      anything, anything, anything)
                .and_return(OpenStruct.new(id: 'no_content_length'))
              deployment = Models::Deployment.create(name: 'foo', manifest: YAML.dump({'foo' => 'bar'}))
              instance = Models::Instance.create(
                deployment: deployment,
                job: 'dea',
                index: '2',
                uuid: '0B949287-CDED-4761-9002-FC4035E11B21',
                state: 'started',
                variable_set: Models::VariableSet.create(deployment: deployment)
              )
              Models::PersistentDisk.create(instance: instance, disk_cid: 'disk_cid')
              put "#{path}", manifest, {'CONTENT_TYPE' => 'text/yaml', 'CONTENT_LENGTH' => '0'}
              match = last_response.location.match(%r{/tasks/no_content_length})
              expect(match).to_not be_nil
            end

            it 'should return 404 if the manifest cannot be found' do
              put "#{path}", asset_content('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml' }
              expect(last_response.status).to eq(404)
            end
          end

          context 'for all jobs in deployment' do
            let(:path) { '/foo/jobs/*?state=stopped' }
            it_behaves_like 'change state'
          end
          context 'for one job in deployment' do
            let(:path) { '/foo/jobs/dea?state=stopped' }
            it_behaves_like 'change state'
          end
          context 'for job instance in deployment by index' do
            let(:path) { '/foo/jobs/dea/2?state=stopped' }
            it_behaves_like 'change state'
          end
          context 'for job instance in deployment by id' do
            let(:path) { '/foo/jobs/dea/0B949287-CDED-4761-9002-FC4035E11B21?state=stopped' }
            it_behaves_like 'change state'
          end

          let(:deployment) do
            Models::Deployment.create(name: 'foo', manifest: YAML.dump({'foo' => 'bar'}))
          end

          it 'allows putting the job instance into different ignore state' do
            instance =
              Models::Instance.create(deployment: deployment, job: 'dea',
                                      index: '0', state: 'started', uuid: '0B949287-CDED-4761-9002-FC4035E11B21',
                                      variable_set: Models::VariableSet.create(deployment: deployment))
            expect(instance.ignore).to be(false)
            put '/foo/instance_groups/dea/0B949287-CDED-4761-9002-FC4035E11B21/ignore', JSON.generate('ignore' => true), { 'CONTENT_TYPE' => 'application/json' }
            expect(last_response.status).to eq(200)
            expect(instance.reload.ignore).to be(true)

            put '/foo/instance_groups/dea/0B949287-CDED-4761-9002-FC4035E11B21/ignore', JSON.generate('ignore' => false), { 'CONTENT_TYPE' => 'application/json' }
            expect(last_response.status).to eq(200)
            expect(instance.reload.ignore).to be(false)
          end

          it 'gives a nice error when uploading non valid manifest' do
            Models::Instance.create(deployment: deployment, job: 'dea',
                                    index: '0', state: 'started',
                                    variable_set: Models::VariableSet.create(deployment: deployment))

            put '/foo/jobs/dea', "}}}i'm not really yaml, hah!", {'CONTENT_TYPE' => 'text/yaml'}

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['code']).to eq(440001)
            expect(JSON.parse(last_response.body)['description']).to include('Incorrect YAML structure of the uploaded manifest: ')
          end

          it 'should not validate body content when content.length is zero' do
            Models::Instance.create(deployment: deployment, job: 'dea',
                                    index: '0', state: 'started',
                                    variable_set: Models::VariableSet.create(deployment: deployment))

            put '/foo/jobs/dea/0?state=started', "}}}i'm not really yaml, hah!", {'CONTENT_TYPE' => 'text/yaml', 'CONTENT_LENGTH' => '0'}

            expect(last_response.status).to eq(302)
          end

          it 'returns a "bad request" if index_or_id parameter of a PUT is neither a number nor a string with uuid format' do
            deployment
            put '/foo/jobs/dea/snoopy?state=stopped', asset_content('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml' }
            expect(last_response.status).to eq(400)
          end

          it 'can get job information' do
            instance = Models::Instance.create(
              deployment: deployment,
              job: 'nats',
              index: '0',
              uuid: 'fake_uuid',
              state: 'started',
              variable_set: Models::VariableSet.create(deployment: deployment)
            )
            Models::PersistentDisk.create(instance: instance, disk_cid: 'disk_cid')

            get '/foo/jobs/nats/0', {}

            expect(last_response.status).to eq(200)
            expected = {
                'deployment' => 'foo',
                'job' => 'nats',
                'index' => 0,
                'id' => 'fake_uuid',
                'state' => 'started',
                'disks' => %w[disk_cid]
            }

            expect(JSON.parse(last_response.body)).to eq(expected)
          end

          it 'should return 404 if the instance cannot be found' do
            get '/foo/jobs/nats/0', {}
            expect(last_response.status).to eq(404)
          end

          context 'with a "canaries" param' do
            it 'overrides the canaries value from the manifest' do
              deployment
              expect_any_instance_of(DeploymentManager)
                .to receive(:create_deployment)
                .with(anything, anything, anything, anything, anything,
                      hash_including('canaries' => '42'), anything)
                .and_return(OpenStruct.new(id: 1))

              put '/foo/jobs/dea?canaries=42', JSON.generate('value' => 'baz'), { 'CONTENT_TYPE' => 'text/yaml' }
              expect(last_response).to be_redirect
            end
          end

          context 'with a "max_in_flight" param' do
            it 'overrides the "max_in_flight" value from the manifest' do
              deployment
              expect_any_instance_of(DeploymentManager)
                .to receive(:create_deployment)
                .with(anything, anything, anything, anything, anything,
                      hash_including('max_in_flight' => '42'), anything)
                .and_return(OpenStruct.new(id: 1))

              put '/foo/jobs/dea?max_in_flight=42', JSON.generate('value' => 'baz'), { 'CONTENT_TYPE' => 'text/yaml' }
              expect(last_response).to be_redirect
            end
          end

          context 'with a "fix" param' do
            it 'passes the parameter' do
              deployment
              expect_any_instance_of(DeploymentManager)
                .to receive(:create_deployment)
                .with(anything, anything, anything, anything, anything,
                      hash_including('fix' => true), anything)
                .and_return(OpenStruct.new(id: 1))

              put '/foo/jobs/dea?fix=true', JSON.generate('value' => 'baz'), {'CONTENT_TYPE' => 'text/yaml'}
              expect(last_response).to be_redirect
            end
          end

          describe 'recreating' do
            let(:context_id) { '' }
            shared_examples_for 'recreates with configs' do
              it 'recreates with the latest configs if you send a manifest' do
                cc_old = Models::Config.create(name: 'cc', type: 'cloud', content: YAML.dump({ 'foo' => 'old-cc' }))
                cc_new = Models::Config.create(name: 'cc', type: 'cloud', content: YAML.dump({ 'foo' => 'new-cc' }))
                runtime_old = Models::Config.create(name: 'runtime', type: 'runtime', content: YAML.dump({ 'foo' => 'old-runtime' }))
                runtime_new = Models::Config.create(name: 'runtime', type: 'runtime', content: YAML.dump({ 'foo' => 'new-runtime' }))

                deployment = Models::Deployment.create(name: 'foo', manifest: YAML.dump({'foo' => 'bar'}))
                deployment.cloud_configs = [cc_old]
                deployment.runtime_configs = [runtime_old]

                instance = Models::Instance.create(
                  deployment: deployment,
                  job: 'dea',
                  index: '2',
                  uuid: '0B949287-CDED-4761-9002-FC4035E11B21',
                  state: 'started',
                  variable_set: Models::VariableSet.create(deployment: deployment)
                )
                expect_any_instance_of(DeploymentManager)
                  .to receive(:create_deployment)
                  .with(anything, anything, [cc_new], [runtime_new], deployment,
                        hash_including(options), context_id)
                  .and_return(OpenStruct.new(id: 1))

                header('X-Bosh-Context-Id', context_id) unless context_id.empty?

                put "#{path}", JSON.generate('value' => 'baz'), {'CONTENT_TYPE' => 'text/yaml'}
                expect(last_response).to be_redirect
              end

              it 'recreates with the previous configs rather than the latest' do
                cc_old = Models::Config.create(name: 'cc', type: 'cloud', content: YAML.dump({ 'foo' => 'old-cc' }))
                cc_new = Models::Config.create(name: 'cc', type: 'cloud', content: YAML.dump({ 'foo' => 'new-cc' }))
                runtime_old = Models::Config.create(name: 'runtime', type: 'runtime', content: YAML.dump({ 'foo' => 'old-runtime' }))
                runtime_new = Models::Config.create(name: 'runtime', type: 'runtime', content: YAML.dump({ 'foo' => 'new-runtime' }))

                deployment = Models::Deployment.create(name: 'foo', manifest: YAML.dump({'foo' => 'bar'}))
                deployment.cloud_configs = [cc_old]
                deployment.runtime_configs = [runtime_old]

                instance = Models::Instance.create(
                  deployment: deployment,
                  job: 'dea',
                  index: '2',
                  uuid: '0B949287-CDED-4761-9002-FC4035E11B21',
                  state: 'started',
                  variable_set: Models::VariableSet.create(deployment: deployment)
                )
                expect_any_instance_of(DeploymentManager)
                  .to receive(:create_deployment)
                  .with(anything, anything, [cc_old], [runtime_old], deployment,
                        hash_including(options), context_id)
                  .and_return(OpenStruct.new(id: 1))

                header('X-Bosh-Context-Id', context_id) unless context_id.empty?
                put "#{path}", '', {'CONTENT_TYPE' => 'text/yaml'}
                expect(last_response).to be_redirect
              end
            end

            context 'with an instance_group' do
              let(:path) {'/foo/jobs/dea?state=recreate'}
              let(:options) do
                { 'job_states' => { 'dea' => { 'state' => 'recreate' } } }
              end
              it_behaves_like 'recreates with configs'
            end

            context 'with an index or ID' do
              let(:path) {'/foo/jobs/dea/2?state=recreate'}
              let(:options) do
                { 'job_states' => { 'dea' => { 'instance_states' => { 2 => 'recreate' } } } }
              end
              it_behaves_like 'recreates with configs'
            end

            context 'accepts a context ID header' do
              let(:context_id) { 'example-context-id' }
              let(:path) { '/foo/jobs/dea?state=recreate' }
              let(:options) do
                { 'job_states' => { 'dea' => { 'state' => 'recreate' } } }
              end
              it_behaves_like 'recreates with configs'
            end
          end

          describe 'draining' do
            let(:deployment) { Models::Deployment.create(name: 'test_deployment', manifest: YAML.dump({ 'foo' => 'bar' })) }
            let(:instance) { Models::Instance.create(deployment: deployment, job: 'job_name', index: '0', uuid: '0B949287-CDED-4761-9002-FC4035E11B21', state: 'started', variable_set: Models::VariableSet.create(deployment: deployment)) }

            before do
              Models::PersistentDisk.create(instance: instance, disk_cid: 'disk_cid')
            end

            shared_examples 'skip_drain' do
              it 'drains' do
                expect_any_instance_of(DeploymentManager)
                  .to receive(:create_deployment)
                  .twice
                  .with(anything, anything, anything, anything, anything,
                        hash_excluding('skip_drain'), anything)
                  .and_return(OpenStruct.new(id: 1))

                put "#{path}", asset_content('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml'}
                expect(last_response).to be_redirect

                put '/test_deployment/jobs/job_name/0B949287-CDED-4761-9002-FC4035E11B21', asset_content('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml' }
                expect(last_response).to be_redirect
              end

              it 'skips draining' do
                expect_any_instance_of(DeploymentManager)
                  .to receive(:create_deployment)
                  .with(anything, anything, anything, anything, anything,
                        hash_including('skip_drain' => drain_target), anything)
                  .and_return(OpenStruct.new(id: 1))

                put "#{path + drain_option}", asset_content('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml'}
                expect(last_response).to be_redirect
              end
            end

            context 'when there is a job instance' do
              let(:path) { '/test_deployment/jobs/job_name/0' }
              let(:drain_option) { '?skip_drain=true' }
              let(:drain_target) { 'job_name' }
              it_behaves_like 'skip_drain'
            end

            context 'when there is a  job' do
              let(:path) { '/test_deployment/jobs/job_name?state=stop' }
              let(:drain_option) { '&skip_drain=true' }
              let(:drain_target) { 'job_name' }
              it_behaves_like 'skip_drain'
            end

            context 'when  deployment' do
              let(:path) { '/test_deployment/jobs/*?state=stop' }
              let(:drain_option) { '&skip_drain=true' }
              let(:drain_target) { '*' }
              it_behaves_like 'skip_drain'
            end
          end
        end

        describe 'log management' do
          it 'allows fetching logs from a particular instance' do
            deployment = Models::Deployment.create(name: 'foo', manifest: YAML.dump({ 'foo' => 'bar' }))
            instance = Models::Instance.create(
              deployment: deployment,
              job: 'nats',
              index: '0',
              state: 'started',
              variable_set: Models::VariableSet.create(deployment: deployment)
            )
            FactoryBot.create(:models_vm, agent_id: 'random-id', instance_id: instance.id, active: true)
            get '/foo/jobs/nats/0/logs', {}
            expect_redirect_to_queued_task(last_response)
          end

          it 'allows fetching logs from all instances of particular job' do
            deployment = Models::Deployment.create(name: 'foo', manifest: YAML.dump({ 'foo' => 'bar' }))
            instance = Models::Instance.create(
              deployment: deployment,
              job: 'nats',
              index: '0',
              state: 'started',
              variable_set: Models::VariableSet.create(deployment: deployment)
            )
            FactoryBot.create(:models_vm, agent_id: 'random-id', instance_id: instance.id, active: true)
            get '/foo/jobs/nats/*/logs', {}
            expect_redirect_to_queued_task(last_response)
          end

          it 'allows fetching logs from all instances of particular deployment' do
            deployment = Models::Deployment.create(name: 'foo', manifest: YAML.dump({ 'foo' => 'bar' }))
            instance = Models::Instance.create(
              deployment: deployment,
              job: 'nats',
              index: '0',
              state: 'started',
              variable_set: Models::VariableSet.create(deployment: deployment)
            )
            FactoryBot.create(:models_vm, agent_id: 'random-id', instance_id: instance.id, active: true)
            get '/foo/jobs/*/*/logs', {}
            expect_redirect_to_queued_task(last_response)
          end

          it '404 if no instance' do
            get '/baz/jobs/nats/0/logs', {}
            expect(last_response.status).to eq(404)
          end

          it '404 if no deployment' do
            deployment = Models::Deployment.
              create(name: 'bar', manifest: YAML.dump({ 'foo' => 'bar' }))
            get '/bar/jobs/nats/0/logs', {}
            expect(last_response.status).to eq(404)
          end
        end

        describe 'listing deployments' do
          let(:deployment) { FactoryBot.create(:models_deployment, name: 'b') }

          before { basic_authorize 'reader', 'reader' }

          context 'with deployment info' do
            before do
              release_1 = Models::Release.create(name: 'release-1')
              release_1_1 = Models::ReleaseVersion.create(release: release_1, version: 1)
              release_1_2 = Models::ReleaseVersion.create(release: release_1, version: 2)
              release_2 = Models::Release.create(name: 'release-2')
              release_2_1 = Models::ReleaseVersion.create(release: release_2, version: 1)

              stemcell_1_1 = Models::Stemcell.create(name: 'stemcell-1', version: 1, cid: 123)
              stemcell_1_2 = Models::Stemcell.create(name: 'stemcell-1', version: 2, cid: 123)
              stemcell_2_1 = Models::Stemcell.create(name: 'stemcell-2', version: 1, cid: 124)

              old_cloud_config = FactoryBot.create(:models_config_cloud, raw_manifest: {}, created_at: Time.now - 60)
              new_cloud_config = FactoryBot.create(:models_config_cloud, raw_manifest: {})
              new_other_cloud_config = FactoryBot.create(:models_config_cloud, name: 'other-config', raw_manifest: {})

              good_team = Models::Team.create(name: 'dabest')
              bad_team = Models::Team.create(name: 'daworst')

              Models::Deployment.create(
                name: 'deployment-3',
              ).tap do |deployment|
                deployment.teams = [bad_team]
              end

              Models::Deployment.create(
                name: 'deployment-2',
              ).tap do |deployment|
                deployment.add_stemcell(stemcell_1_1)
                deployment.add_stemcell(stemcell_1_2)
                deployment.add_release_version(release_1_1)
                deployment.add_release_version(release_2_1)
                deployment.teams = [good_team]
                deployment.cloud_configs = [new_other_cloud_config, new_cloud_config]
              end

              Models::Deployment.create(
                name: 'deployment-1',
              ).tap do |deployment|
                deployment.add_stemcell(stemcell_1_1)
                deployment.add_stemcell(stemcell_2_1)
                deployment.add_release_version(release_1_1)
                deployment.add_release_version(release_1_2)
                deployment.teams = [good_team, bad_team]
                deployment.cloud_configs = [old_cloud_config]
              end

              Models::Lock.create(name: 'lock:deployment:deployment-2', uid: 'who-cares', expired_at: Time.now + 100000)
            end

            context 'with cloud configs' do
              it 'excludes non-cloud configs' do
                old_runtime = FactoryBot.create(:models_config_runtime, name: 'runtime-config', raw_manifest: {})
                FactoryBot.create(:models_config_runtime, name: 'runtime-config', raw_manifest: {})
                Models::Deployment.create(
                  name: 'deployment-4',
                ).tap do |deployment|
                  deployment.runtime_configs = [old_runtime]
                end

                get '/', {}, {}
                expect(last_response.status).to eq(200)
                body = JSON.parse(last_response.body)

                expect(body).to eq(
                  [
                    {
                      'name' => 'deployment-1',
                      'releases' => [
                        { 'name' => 'release-1', 'version' => '1' },
                        { 'name' => 'release-1', 'version' => '2' },
                      ],
                      'stemcells' => [
                        { 'name' => 'stemcell-1', 'version' => '1' },
                        { 'name' => 'stemcell-2', 'version' => '1' },
                      ],
                      'cloud_config' => 'outdated',
                      'teams' => %w[dabest daworst],
                      'locked' => false,
                    },
                    {
                      'name' => 'deployment-2',
                      'releases' => [
                        { 'name' => 'release-1', 'version' => '1' },
                        { 'name' => 'release-2', 'version' => '1' },
                      ],
                      'stemcells' => [
                        { 'name' => 'stemcell-1', 'version' => '1' },
                        { 'name' => 'stemcell-1', 'version' => '2' },
                      ],
                      'cloud_config' => 'latest',
                      'teams' => ['dabest'],
                      'locked' => true,
                    },
                    {
                      'name' => 'deployment-3',
                      'releases' => [],
                      'stemcells' => [],
                      'cloud_config' => 'none',
                      'teams' => ['daworst'],
                      'locked' => false,
                    },
                    {
                      'name' => 'deployment-4',
                      'releases' => [],
                      'stemcells' => [],
                      'cloud_config' => 'none',
                      'teams' => [],
                      'locked' => false,
                    },
                  ],
                )
              end

              it 'mark cloud-config outdated if it references a deleted config' do
                deleted_cloud_config = FactoryBot.create(:models_config_cloud, raw_manifest: {}, deleted: true)
                Models::Deployment.create(
                  name: 'deployment-4',
                ).tap do |deployment|
                  deployment.cloud_configs = [deleted_cloud_config]
                end

                get '/', {}, {}
                expect(last_response.status).to eq(200)
                body = JSON.parse(last_response.body)

                expect(body).to eq(
                  [
                    {
                      'name' => 'deployment-1',
                      'releases' => [
                        { 'name' => 'release-1', 'version' => '1' },
                        { 'name' => 'release-1', 'version' => '2' },
                      ],
                      'stemcells' => [
                        { 'name' => 'stemcell-1', 'version' => '1' },
                        { 'name' => 'stemcell-2', 'version' => '1' },
                      ],
                      'cloud_config' => 'outdated',
                      'teams' => %w[dabest daworst],
                      'locked' => false,
                    },
                    {
                      'name' => 'deployment-2',
                      'releases' => [
                        { 'name' => 'release-1', 'version' => '1' },
                        { 'name' => 'release-2', 'version' => '1' },
                      ],
                      'stemcells' => [
                        { 'name' => 'stemcell-1', 'version' => '1' },
                        { 'name' => 'stemcell-1', 'version' => '2' },
                      ],
                      'cloud_config' => 'outdated',
                      'teams' => ['dabest'],
                      'locked' => true,
                    },
                    {
                      'name' => 'deployment-3',
                      'releases' => [],
                      'stemcells' => [],
                      'cloud_config' => 'none',
                      'teams' => ['daworst'],
                      'locked' => false,
                    },
                    {
                      'name' => 'deployment-4',
                      'releases' => [],
                      'stemcells' => [],
                      'cloud_config' => 'outdated',
                      'teams' => [],
                      'locked' => false,
                    },
                  ],
                )
              end
            end

            it 'lists in name order' do
              get '/', {}, {}
              expect(last_response.status).to eq(200)

              body = JSON.parse(last_response.body)
              expect(body).to eq(
                [
                  {
                    'name' => 'deployment-1',
                    'releases' => [
                      { 'name' => 'release-1', 'version' => '1' },
                      { 'name' => 'release-1', 'version' => '2' },
                    ],
                    'stemcells' => [
                      { 'name' => 'stemcell-1', 'version' => '1' },
                      { 'name' => 'stemcell-2', 'version' => '1' },
                    ],
                    'cloud_config' => 'outdated',
                    'teams' => %w[dabest daworst],
                    'locked' => false,
                  },
                  {
                    'name' => 'deployment-2',
                    'releases' => [
                      { 'name' => 'release-1', 'version' => '1' },
                      { 'name' => 'release-2', 'version' => '1' },
                    ],
                    'stemcells' => [
                      { 'name' => 'stemcell-1', 'version' => '1' },
                      { 'name' => 'stemcell-1', 'version' => '2' },
                    ],
                    'cloud_config' => 'latest',
                    'teams' => ['dabest'],
                    'locked' => true,
                  },
                  {
                    'name' => 'deployment-3',
                    'releases' => [],
                    'stemcells' => [],
                    'cloud_config' => 'none',
                    'teams' => ['daworst'],
                    'locked' => false,
                  },
                ],
              )
            end

            it 'lists without configs if specified' do
              get '/?exclude_configs=true', {}, {}
              expect(last_response.status).to eq(200)

              body = JSON.parse(last_response.body)
              expect(body).to eq(
                [
                  {
                    'name' => 'deployment-1',
                    'releases' => [
                      { 'name' => 'release-1', 'version' => '1' },
                      { 'name' => 'release-1', 'version' => '2' },
                    ],
                    'stemcells' => [
                      { 'name' => 'stemcell-1', 'version' => '1' },
                      { 'name' => 'stemcell-2', 'version' => '1' },
                    ],
                    'teams' => %w[dabest daworst],
                    'locked' => false,
                  },
                  {
                    'name' => 'deployment-2',
                    'releases' => [
                      { 'name' => 'release-1', 'version' => '1' },
                      { 'name' => 'release-2', 'version' => '1' },
                    ],
                    'stemcells' => [
                      { 'name' => 'stemcell-1', 'version' => '1' },
                      { 'name' => 'stemcell-1', 'version' => '2' },
                    ],
                    'teams' => ['dabest'],
                    'locked' => true,
                  },
                  {
                    'name' => 'deployment-3',
                    'releases' => [],
                    'stemcells' => [],
                    'teams' => ['daworst'],
                    'locked' => false,
                  },
                ],
              )
            end

            it 'lists without configs,stemcells and releases if specified' do
              get '/?exclude_configs=true&exclude_stemcells=true&exclude_releases=true&exclude_lock=true', {}, {}
              expect(last_response.status).to eq(200)

              body = JSON.parse(last_response.body)
              expect(body).to eq(
                [
                  {
                    'name' => 'deployment-1',
                    'teams' => %w[dabest daworst],
                  },
                  {
                    'name' => 'deployment-2',
                    'teams' => ['dabest'],
                  },
                  {
                    'name' => 'deployment-3',
                    'teams' => ['daworst'],
                  },
                ],
              )
            end
          end

          it 'orders the associations' do
            release2 = FactoryBot.create(:models_release, name: 'r2')
            release1 = FactoryBot.create(:models_release, name: 'r1')

            deployment.add_release_version(FactoryBot.create(:models_release_version, version: '3', release_id: release1.id))
            deployment.add_release_version(FactoryBot.create(:models_release_version, version: '2', release_id: release1.id))
            deployment.add_release_version(FactoryBot.create(:models_release_version, version: '1', release_id: release2.id))

            deployment.add_team(FactoryBot.create(:models_team, name: 'team2'))
            deployment.add_team(FactoryBot.create(:models_team, name: 'team3'))
            deployment.add_team(FactoryBot.create(:models_team, name: 'team1'))

            deployment.add_stemcell(FactoryBot.create(:models_stemcell, name: 'stemcell2', version: '4'))
            deployment.add_stemcell(FactoryBot.create(:models_stemcell, name: 'stemcell1', version: '1'))
            deployment.add_stemcell(FactoryBot.create(:models_stemcell, name: 'stemcell2', version: '3'))
            deployment.add_stemcell(FactoryBot.create(:models_stemcell, name: 'stemcell3', version: '2'))

            get '/', {}, {}
            expect(last_response.status).to eq(200)

            body = JSON.parse(last_response.body)

            expect(body.first['releases']).to eq([{'name' => 'r1', 'version' => '2'}, {'name' => 'r1', 'version' => '3'}, {'name' => 'r2', 'version' => '1'}])
            expect(body.first['stemcells']).to eq([
                {'name' => 'stemcell1', 'version' => '1'},
                {'name' => 'stemcell2', 'version' => '3'},
                {'name' => 'stemcell2', 'version' => '4'},
                {'name' => 'stemcell3', 'version' => '2'}])
            expect(body.first['teams']).to eq(%w(team1 team2 team3))
          end

          context 'when authorized as a team reader' do
            let!(:permitted_deployment) do
              Models::Deployment.create(
                name: 'deployment-1',
              ).tap do |deployment|
                deployment.teams = [dev_team]
                deployment.cloud_configs = [dev_cloud_config]
              end
            end
            let!(:unauthorized_deployment) do
              Models::Deployment.create(
                name: 'deployment-2',
              ).tap do |deployment|
                deployment.teams = [other_team]
                deployment.cloud_configs = [other_cloud_config]
              end
            end
            let(:other_team) { FactoryBot.create(:models_team, name: 'footeam') }
            let(:dev_team) { FactoryBot.create(:models_team, name: 'dev') }
            let(:dev_cloud_config) do
              FactoryBot.create(:models_config_cloud, name: 'dev-team-config', raw_manifest: {}, team_id: dev_team.id)
            end
            let(:other_cloud_config) do
              FactoryBot.create(:models_config_cloud, name: 'other-team-config', raw_manifest: {}, team_id: other_team.id)
            end

            before { basic_authorize 'dev-team-member', 'dev-team-member' }

            it 'returns the deployments that the user has access to with correct cloud-config status' do
              get '/', {}, {}
              expect(last_response.status).to eq(200)

              body = JSON.parse(last_response.body)
              expect(body).to eq([
                {
                  'name' => 'deployment-1',
                  'releases' => [],
                  'stemcells' => [],
                  'cloud_config' => 'latest',
                  'teams' => ['dev'],
                  'locked' => false,
                },
              ])
            end
          end
        end

        describe 'getting deployment info' do
          before { basic_authorize 'reader', 'reader' }

          it 'returns manifest' do
            deployment = Models::Deployment.
                create(name: 'test_deployment',
                       manifest_text: YAML.dump({ 'foo' => 'bar' }))
            get '/test_deployment'

            expect(last_response.status).to eq(200)
            body = JSON.parse(last_response.body)
            expect(YAML.load(body['manifest'])).to eq('foo' => 'bar')
          end
        end

        describe 'getting deployment vms info' do
          before { basic_authorize 'reader', 'reader' }

          let(:deployment) { Models::Deployment.create(name: 'test_deployment', manifest: YAML.dump({ 'foo' => 'bar' })) }

          it 'returns a list of instances with vms (vm_cid != nil)' do
            8.times do |i|
              instance_params = {
                'deployment_id' => deployment.id,
                'job' => "job-#{i}",
                'index' => i,
                'state' => 'started',
                'uuid' => "instance-#{i}",
                'variable_set_id' => (Models::VariableSet.create(deployment: deployment).id),
                'spec' => {'networks' => {'network1' => {'ip' => "#{i}.#{i}.#{i}.#{i}"}}},
              }

              instance_params['availability_zone'] = 'az0' if i == 0
              instance_params['availability_zone'] = 'az1' if i == 1
              instance = Models::Instance.create(instance_params)
              2.times do |j|
                vm_params = {
                  'agent_id' => "agent-#{i}-#{j}",
                  'cid' => "cid-#{i}-#{j}",
                  'instance_id' => instance.id,
                  'created_at' => time,
                  'network_spec' => {'network1' => {'ip' => "#{i}.#{i}.#{j}.#{j}"}},
                }

                vm = Models::Vm.create(vm_params)

                if j == 0
                  instance.active_vm = vm
                end
              end
            end

            get '/test_deployment/vms'

            expect(last_response.status).to eq(200)
            body = JSON.parse(last_response.body)
            expect(body.size).to eq(16)
            body.sort_by{|instance| instance['agent_id']}.each_with_index do |instance_with_vm, i|
              instance_idx = i / 2
              vm_by_instance = i % 2
              vm_is_active = vm_by_instance == 0
              expect(instance_with_vm).to eq(
                'agent_id' => "agent-#{instance_idx}-#{vm_by_instance}",
                'job' => "job-#{instance_idx}",
                'index' => instance_idx,
                'cid' => "cid-#{instance_idx}-#{vm_by_instance}",
                'id' => "instance-#{instance_idx}",
                'active' => vm_is_active,
                'az' => {0 => 'az0', 1 => 'az1', nil => nil}[instance_idx],
                'ips' => ["#{instance_idx}.#{instance_idx}.#{vm_by_instance}.#{vm_by_instance}"],
                'vm_created_at' => time.utc.iso8601,
                'permanent_nats_credentials' => false,
              )
            end
          end

          context 'with full format requested' do
            before do
              deployment
            end

            it 'redirects to a delayed job' do
              expect_any_instance_of(Api::InstanceManager).to receive(:fetch_instances_with_vm) do
                FactoryBot.create(:models_task, id: 10002)
              end

              get '/test_deployment/vms?format=full'

              task = expect_redirect_to_queued_task(last_response)
              expect(task.id).to eq 10002
            end
          end

          context 'ips' do
            it 'returns ip addresses for each vm' do
              9.times do |i|
                instance_params = {
                  'deployment_id' => deployment.id,
                  'job' => "job-#{i}",
                  'index' => i,
                  'state' => 'started',
                  'uuid' => "instance-#{i}",
                  'variable_set_id' => (Models::VariableSet.create(deployment: deployment).id)
                }

                instance_params['availability_zone'] = 'az0' if i == 0
                instance_params['availability_zone'] = 'az1' if i == 1
                instance = Models::Instance.create(instance_params)

                2.times do |j|
                  vm_params = {
                    'agent_id' => "agent-#{i}-#{j}",
                    'cid' => "cid-#{i}-#{j}",
                    'instance_id' => instance.id,
                    'created_at' => time,
                  }

                  vm = Models::Vm.create(vm_params)

                  if j == 0
                    instance.active_vm = vm
                  end

                  ip_addresses_params = {
                    'instance_id' => instance.id,
                    'task_id' => i.to_s,
                    'address_str' => ip_to_i("1.2.#{i}.#{j}").to_s,
                    'vm_id' => vm.id,
                  }
                  Models::IpAddress.create(ip_addresses_params)
                end
              end

              get '/test_deployment/vms'

              expect(last_response.status).to eq(200)
              body = JSON.parse(last_response.body)
              expect(body.size).to eq(18)

              body.sort_by { |instance| instance['agent_id'] }.each_with_index do |instance_with_vm, i|
                instance_idx = i / 2
                vm_by_instance = i % 2
                vm_is_active = vm_by_instance == 0
                expect(instance_with_vm).to eq(
                  'agent_id' => "agent-#{instance_idx}-#{vm_by_instance}",
                  'job' => "job-#{instance_idx}",
                  'index' => instance_idx,
                  'cid' => "cid-#{instance_idx}-#{vm_by_instance}",
                  'id' => "instance-#{instance_idx}",
                  'active' => vm_is_active,
                  'az' => { 0 => 'az0', 1 => 'az1', nil => nil }[instance_idx],
                  'ips' => ["1.2.#{instance_idx}.#{vm_by_instance}"],
                  'vm_created_at' => time.utc.iso8601,
                  'permanent_nats_credentials' => false,
                )
              end
            end

            it 'returns network spec ip addresses' do
              15.times do |i|
                instance_params = {
                  'deployment_id' => deployment.id,
                  'job' => "job-#{i}",
                  'index' => i,
                  'state' => 'started',
                  'variable_set_id' => (Models::VariableSet.create(deployment: deployment).id),
                  'uuid' => "instance-#{i}",
                }

                instance_params['availability_zone'] = 'az0' if i == 0
                instance_params['availability_zone'] = 'az1' if i == 1
                instance = Models::Instance.create(instance_params)
                vm_params = {
                  'agent_id' => "agent-#{i}",
                  'cid' => "cid-#{i}",
                  'instance_id' => instance.id,
                  'created_at' => time,
                  'network_spec' => {'network1' => {'ip' => "1.2.3.#{i}"}},
                }

                vm = Models::Vm.create(vm_params)
                if i < 8
                  instance.active_vm = vm
                end
              end

              get '/test_deployment/vms'

              expect(last_response.status).to eq(200)
              body = JSON.parse(last_response.body)
              expect(body.size).to eq(15)

              body.sort_by{|instance| instance['index']}.each_with_index do |instance_with_vm, i|
                vm_is_active = i < 8
                expect(instance_with_vm).to eq(
                  'agent_id' => "agent-#{i}",
                  'job' => "job-#{i}",
                  'index' => i,
                  'cid' => "cid-#{i}",
                  'id' => "instance-#{i}",
                  'active' => vm_is_active,
                  'az' => {0 => 'az0', 1 => 'az1', nil => nil}[i],
                  'ips' => ["1.2.3.#{i}"],
                  'vm_created_at' => time.utc.iso8601,
                  'permanent_nats_credentials' => false,
                )
              end
            end

            it 'returns vip and network_spec ip addresses for a vm' do
              vip = '1.2.3.4'
              network_spec_ip = '4.3.2.1'

              instance_params = {
                'availability_zone' => 'az0',
                'deployment_id' => deployment.id,
                'index' => 0,
                'job' => 'job',
                'state' => 'started',
                'uuid' => 'instance-id',
                'variable_set_id' => Models::VariableSet.create(deployment: deployment).id,
              }

              instance = Models::Instance.create(instance_params)

              vm_params = {
                'agent_id' => 'agent-id',
                'cid' => 'cid',
                'created_at' => time,
                'instance_id' => instance.id,
                'network_spec' => {
                  'network1' => { 'ip' => network_spec_ip },
                  'network2' => { 'ip' => vip },
                },
              }

              vm = Models::Vm.create(vm_params)
              instance.active_vm = vm

              ip_addresses_params = {
                'address_str' => ip_to_i(vip).to_s,
                'instance_id' => instance.id,
                'task_id' => '1',
                'vm_id' => vm.id,
              }
              Models::IpAddress.create(ip_addresses_params)

              get '/test_deployment/vms'

              expect(last_response.status).to eq(200)
              body = JSON.parse(last_response.body)
              expect(body.size).to eq(1)

              expect(body.first).to eq(
                'active' => true,
                'agent_id' => 'agent-id',
                'az' => 'az0',
                'cid' => 'cid',
                'id' => 'instance-id',
                'index' => 0,
                'ips' => [vip, network_spec_ip],
                'job' => 'job',
                'vm_created_at' => time.utc.iso8601,
                'permanent_nats_credentials' => false,
              )
            end
          end
        end

        describe 'getting deployment instances' do
          before do
            basic_authorize 'reader', 'reader'
            release = Models::Release.create(name: 'test_release')
            version = Models::ReleaseVersion.create(release: release, version: 1)
            version.add_template(FactoryBot.create(:models_template, name: 'job_using_pkg_1', release: release))
          end
          let(:deployment) { Models::Deployment.create(name: 'test_deployment', manifest: manifest) }
          let(:default_manifest) { SharedSupport::DeploymentManifestHelper.minimal_manifest }

          context 'multiple instances' do
            let(:manifest) do
              jobs = []
              15.times do |i|
                jobs << {
                  'name' => "job-#{i}",
                  'spec' => { 'templates' => [{ 'name' => 'job_using_pkg_1' }] },
                  'instances' => 1,
                  'networks' => [{ 'name' => 'a' }],
                }
              end
              YAML.dump(default_manifest.merge('jobs' => jobs))
            end

            it 'returns all' do
              15.times do |i|
                instance_params = {
                    'deployment_id' => deployment.id,
                    'job' => "job-#{i}",
                    'index' => i,
                    'state' => 'started',
                    'variable_set_id' => (Models::VariableSet.create(deployment: deployment).id),
                    'uuid' => "instance-#{i}",
                    'spec_json' => '{ "lifecycle": "service" }',
                }

                instance_params['availability_zone'] = 'az0' if i == 0
                instance_params['availability_zone'] = 'az1' if i == 1
                instance = Models::Instance.create(instance_params)
                if i < 6
                  vm_params = {
                    'agent_id' => "agent-#{i}",
                    'cid' => "cid-#{i}",
                    'instance_id' => instance.id,
                    'created_at' => time,
                    'network_spec' => {}
                  }

                  vm = Models::Vm.create(vm_params)
                  instance.active_vm = vm
                end

              end

              get '/test_deployment/instances'

              expect(last_response.status).to eq(200)
              body = JSON.parse(last_response.body)
              expect(body.size).to eq(15)

              body.sort_by{|instance| instance['index']}.each_with_index do |instance, i|
                if i < 6
                  expect(instance).to eq(
                    'agent_id' => "agent-#{i}",
                    'cid' => "cid-#{i}",
                    'job' => "job-#{i}",
                    'index' => i,
                    'id' => "instance-#{i}",
                    'az' => {0 => 'az0', 1 => 'az1', nil => nil}[i],
                    'ips' => [],
                    'vm_created_at' => time.utc.iso8601,
                    'expects_vm' => true
                  )
                else
                  expect(instance).to eq(
                    'agent_id' => nil,
                    'cid' => nil,
                    'job' => "job-#{i}",
                    'index' => i,
                    'id' => "instance-#{i}",
                    'az' => {0 => 'az0', 1 => 'az1', nil => nil}[i],
                    'ips' => [],
                    'vm_created_at' => nil,
                    'expects_vm' => true
                  )
                end
              end
            end

            context 'ips' do
              it 'returns no ips if there are no vms for the instance' do
                15.times do |i|
                  instance_params = {
                      'deployment_id' => deployment.id,
                      'job' => "job-#{i}",
                      'index' => i,
                      'state' => 'started',
                      'variable_set_id' => (Models::VariableSet.create(deployment: deployment).id),
                      'uuid' => "instance-#{i}",
                      'spec_json' => '{ "lifecycle": "service" }',
                  }

                  instance_params['availability_zone'] = 'az0' if i == 0
                  instance_params['availability_zone'] = 'az1' if i == 1
                  instance = Models::Instance.create(instance_params)

                  ip_addresses_params  = {
                    'instance_id' => instance.id,
                    'task_id' => "#{i}",
                    'address_str' => ip_to_i("1.2.3.#{i}").to_s,
                  }
                  Models::IpAddress.create(ip_addresses_params)
                end

                get '/test_deployment/instances'

                expect(last_response.status).to eq(200)
                body = JSON.parse(last_response.body)
                expect(body.size).to eq(15)

                body.sort_by{|instance| instance['index']}.each_with_index do |instance, i|
                  expect(instance).to eq(
                                          'agent_id' => nil,
                                          'cid' => nil,
                                          'job' => "job-#{i}",
                                          'index' => i,
                                          'id' => "instance-#{i}",
                                          'az' => {0 => 'az0', 1 => 'az1', nil => nil}[i],
                                          'ips' => [],
                                          'vm_created_at' => nil,
                                          'expects_vm' => true
                                      )
                end
              end

              it 'returns no ips even if there is a network spec ip addresses' do
                15.times do |i|
                  instance_params = {
                      'deployment_id' => deployment.id,
                      'job' => "job-#{i}",
                      'index' => i,
                      'state' => 'started',
                      'variable_set_id' => (Models::VariableSet.create(deployment: deployment).id),
                      'uuid' => "instance-#{i}",
                      'spec_json' => "{ \"lifecycle\": \"service\", \"networks\": [ [ \"a\", { \"ip\": \"1.2.3.#{i}\" } ] ] }",
                  }

                  instance_params['availability_zone'] = 'az0' if i == 0
                  instance_params['availability_zone'] = 'az1' if i == 1
                  Models::Instance.create(instance_params)
                end

                get '/test_deployment/instances'

                expect(last_response.status).to eq(200)
                body = JSON.parse(last_response.body)
                expect(body.size).to eq(15)

                body.sort_by{|instance| instance['index']}.each_with_index do |instance, i|
                  expect(instance).to eq(
                                          'agent_id' => nil,
                                          'cid' => nil,
                                          'job' => "job-#{i}",
                                          'index' => i,
                                          'id' => "instance-#{i}",
                                          'az' => {0 => 'az0', 1 => 'az1', nil => nil}[i],
                                          'ips' => [],
                                          'vm_created_at' => nil,
                                          'expects_vm' => true
                                      )
                end
              end
            end
          end

          context 'instance lifecycle' do
            let(:job_state) { 'started' }
            before do
              Models::Instance.create({
                                          'deployment_id' => deployment.id,
                                          'job' => 'job',
                                          'index' => 1,
                                          'state' => job_state,
                                          'variable_set_id' => (Models::VariableSet.create(deployment: deployment).id),
                                          'uuid' => 'instance-1',
                                          'spec_json' => "{ \"lifecycle\": \"#{instance_lifecycle}\" }",
                                      })
            end

            context 'is "service"' do
              let(:manifest) { YAML.dump(default_manifest.merge(SharedSupport::DeploymentManifestHelper.simple_instance_group)) }
              let(:instance_lifecycle) { 'service' }

              context 'and state is either "started" or "stopped"' do
                it 'sets "expects_vm" to "true"' do

                  get '/test_deployment/instances'

                  expect(last_response.status).to eq(200)
                  body = JSON.parse(last_response.body)
                  expect(body.size).to eq(1)

                  expect(body[0]).to eq(
                                         'agent_id' => nil,
                                         'cid' => nil,
                                         'job' => 'job',
                                         'index' => 1,
                                         'id' => 'instance-1',
                                         'az' => nil,
                                         'ips' => [],
                                         'vm_created_at' => nil,
                                         'expects_vm' => true
                                     )
                end
              end

              context 'and state is "detached"' do
                let(:job_state) { 'detached'}
                it 'sets "expects_vm" to "false"' do

                  get '/test_deployment/instances'

                  expect(last_response.status).to eq(200)
                  body = JSON.parse(last_response.body)
                  expect(body.size).to eq(1)

                  expect(body[0]).to eq(
                                         'agent_id' => nil,
                                         'cid' => nil,
                                         'job' => 'job',
                                         'index' => 1,
                                         'id' => 'instance-1',
                                         'az' => nil,
                                         'ips' => [],
                                         'vm_created_at' => nil,
                                         'expects_vm' => false
                                     )
                end
              end
            end

            context 'is "errand"' do
              let(:manifest) { YAML.dump(default_manifest.merge(SharedSupport::DeploymentManifestHelper.simple_instance_group)) }
              let(:instance_lifecycle) { 'errand' }

              it 'sets "expects_vm" to "false"' do
                get '/test_deployment/instances'

                expect(last_response.status).to eq(200)
                body = JSON.parse(last_response.body)
                expect(body.size).to eq(1)

                expect(body[0]).to eq(
                                       'agent_id' => nil,
                                       'cid' => nil,
                                       'job' => 'job',
                                       'index' => 1,
                                       'id' => 'instance-1',
                                       'az' => nil,
                                       'ips' => [],
                                       'vm_created_at' => nil,
                                       'expects_vm' => false
                                   )
              end
            end
          end
        end

        describe 'getting deployment certificates expiry' do
          let(:deployment_cert_provider) { instance_double(Bosh::Director::Api::DeploymentCertificateProvider) }
          let(:certificate_list) do
            [
              {
                'name' => '/director/test_deployment/broker_cert',
                'id' => 1,
                'expiry_date' => /.*/,
                'days_left' => 29,
              },
              {
                'name' => '/director/test_deployment/master_root_ca',
                'id' => 2,
                'expiry_date' => /.*/,
                'days_left' => 0,
              },
              {
                'name' => '/director/test_deployment/server_cert',
                'id' => 3,
                'expiry_date' => /.*/,
                'days_left' => -2,
              },
            ]
          end

          before(:each) do
            FactoryBot.create(:models_deployment, name: 'test_deployment', manifest: '----')
            allow(Bosh::Director::Api::DeploymentCertificateProvider).to receive(:new).and_return(deployment_cert_provider)
            allow(deployment_cert_provider).to receive(:list_certificates_with_expiry).and_return(certificate_list)
          end

          it 'returns the certificate path and expiry for a deployment' do
            get 'test_deployment/certificate_expiry'

            expect(last_response.status).to eq(200)
            body = JSON.parse(last_response.body)

            expect(body.size).to eq(3)
            expect(body).to include('name' => '/director/test_deployment/broker_cert',
                                    'id' => 1, 'expiry_date' => /.*/, 'days_left' => 29)
            expect(body).to include('name' => '/director/test_deployment/master_root_ca',
                                    'id' => 2, 'expiry_date' => /.*/, 'days_left' => 0)
            expect(body).to include('name' => '/director/test_deployment/server_cert',
                                    'id' => 3, 'expiry_date' => /.*/, 'days_left' => -2)
          end

          context 'if no certificates are associated with deployment' do
            let(:certificate_list) { [] }
            it 'returns 0 items if there are no certificates' do
              get 'test_deployment/certificate_expiry'

              expect(last_response.status).to eq(200)
              body = JSON.parse(last_response.body)
              expect(body.size).to eq(0)
            end
          end
        end

        describe 'problem management' do
          let!(:deployment) { FactoryBot.create(:models_deployment, name: 'mycloud') }
          let(:job_class) do
            Class.new(Jobs::CloudCheck::ScanAndFix) do
              define_method :perform do
                'foo'
              end
              @queue = :normal
            end
          end
          let(:db_job) { Jobs::DBJob.new(job_class, task.id, args)}

          it 'exposes problem management REST API' do
            get '/mycloud/problems'
            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body)).to eq([])

            post '/mycloud/scans'
            expect_redirect_to_queued_task(last_response)

            put '/mycloud/problems', JSON.generate(
              'resolutions' => { 42 => 'do_this', 43 => 'do_that', 44 => nil },
              'max_in_flight_overrides' => {'diego_cell' => '3', 'router' => '50%'},
            ), { 'CONTENT_TYPE' => 'application/json' }
            expect_redirect_to_queued_task(last_response)

            put '/mycloud/problems', JSON.generate('solution' => 'default'), { 'CONTENT_TYPE' => 'application/json' }
            expect_redirect_to_queued_task(last_response)
          end

          context 'fixing problems' do
            let(:resolutions) do
              { '1' => 'foo', '4' => 'bar' }
            end

            let(:max_in_flight_overrides) do
              { 'router' => '3', 'diego_cell' => '50%' }
            end

            before do
              expect_any_instance_of(ProblemManager)
                .to receive(:apply_resolutions)
                .with(anything, deployment, resolutions, max_in_flight_overrides)
                .and_return(FactoryBot.create(:models_task))
            end

            it 'should pass resolutions and overrides to the problem manager' do
              put '/mycloud/problems', JSON.generate(
                'resolutions' => resolutions,
                'max_in_flight_overrides' => max_in_flight_overrides,
              ), { 'CONTENT_TYPE' => 'application/json' }
              expect_redirect_to_queued_task(last_response)
            end

            context 'when no max_in_flight_overrides are provided' do
              let!(:max_in_flight_overrides) { {} }

              it 'should pass an empty hash for overrides to the problem manager' do
                put '/mycloud/problems', JSON.generate(
                  'resolutions' => resolutions,
                ), { 'CONTENT_TYPE' => 'application/json' }
                expect_redirect_to_queued_task(last_response)
              end
            end
          end

          context 'listing problems' do
            let(:problems) do
              [
                Models::DeploymentProblem.
                create(deployment_id: deployment.id, resource_id: 2,
                       type: 'unresponsive_agent', state: 'open', data: {}),
                Models::DeploymentProblem.
                  create(deployment_id: deployment.id, resource_id: 3,
                         type: 'unresponsive_agent', state: 'open', data: {})
              ]
            end
            let(:handler) { instance_double(ProblemHandlers::UnresponsiveAgent) }

            before do
              allow(handler).to receive(:description).and_return('description', 'other_description')
              allow(handler).to receive(:resolutions).and_return([1,2], [3,4])
              allow(handler).to receive(:instance_group).and_return('router', 'diego_cell')

              allow(problems[0])
                .to receive(:handler).and_return(handler)
              allow(problems[1])
                .to receive(:handler).and_return(handler)

              expect_any_instance_of(ProblemManager)
                .to receive(:get_problems).with(deployment).and_return(problems)
            end

            it 'correctly renders problems' do
              get '/mycloud/problems'
              expect(last_response.status).to eq(200)
              expect(JSON.parse(last_response.body)).to eq(
                [
                  {
                    'data' => {},
                    'description' => 'description',
                    'id' => 1,
                    'resolutions' => [1, 2],
                    'type' => 'unresponsive_agent',
                    'instance_group' => 'router',
                  },
                  {
                    'data' => {},
                    'description' => 'other_description',
                    'id' => 2,
                    'resolutions' => [3, 4],
                    'type' => 'unresponsive_agent',
                    'instance_group' => 'diego_cell',
                  }
                ]
              )
            end
          end
        end

        describe 'resurrection' do
          let!(:deployment) { FactoryBot.create(:models_deployment, name: 'mycloud') }

          def should_not_enqueue_scan_and_fix(expected_status, dep = 'mycloud')
            expect(Bosh::Director::Jobs::DBJob).not_to receive(:new).with(
              Jobs::CloudCheck::ScanAndFix,
              kind_of(Numeric),
              [dep,
              [['job', 0]], false])
            expect(Delayed::Job).not_to receive(:enqueue)
            put "/#{dep}/scan_and_fix", JSON.dump('jobs' => { 'job' => [0] }), 'CONTENT_TYPE' => 'application/json'
            expect(last_response.status).to eq(expected_status)
          end

          def should_enqueue_scan_and_fix
            expect(Bosh::Director::Jobs::DBJob).to receive(:new).with(
              Jobs::CloudCheck::ScanAndFix,
              kind_of(Numeric),
              ['mycloud',
              [['job', 0]], false])
            expect(Delayed::Job).to receive(:enqueue)
            put '/mycloud/scan_and_fix', JSON.generate('jobs' => { 'job' => [0] }), 'CONTENT_TYPE' => 'application/json'
            expect_redirect_to_queued_task(last_response)
          end

          context 'when global resurrection is not set' do
            it 'scans and fixes problems' do
              FactoryBot.create(:models_instance, deployment: deployment, job: 'job', index: 0)
              should_enqueue_scan_and_fix
            end
          end

          context 'when global resurrection is set' do
            before { FactoryBot.create(:models_director_attribute, name: 'resurrection_paused', value: resurrection_paused) }

            context 'when global resurrection is on' do
              let(:resurrection_paused) {'false'}

              it 'runs scan_and_fix task' do
                FactoryBot.create(:models_instance, deployment: deployment, job: 'job', index: 0)
                should_enqueue_scan_and_fix
              end
            end

            context 'when global resurrection is off' do
              let(:resurrection_paused) {'true'}

              it 'does not run scan_and_fix task' do
                FactoryBot.create(:models_instance, deployment: deployment, job: 'job', index: 0)
                should_not_enqueue_scan_and_fix(400)
              end
            end
          end

          context 'when there are only ignored vms' do
            it 'does not call the resurrector' do
              FactoryBot.create(:models_instance, deployment: deployment, job: 'job', index: 0, ignore: true)
              should_not_enqueue_scan_and_fix(404)
            end
          end

          context 'when the deployment does not exist' do
            it 'does not call the resurrector' do
              should_not_enqueue_scan_and_fix(404, 'nonsense')
            end
          end
        end

        describe 'snapshots' do
          before do
            deployment = FactoryBot.create(:models_deployment, name: 'mycloud')

            instance = FactoryBot.create(:models_instance, deployment: deployment, job: 'job', index: 0, uuid: 'abc123')
            disk = FactoryBot.create(:models_persistent_disk, disk_cid: 'disk0', instance: instance, active: true)
            FactoryBot.create(:models_snapshot, persistent_disk: disk, snapshot_cid: 'snap0a')

            instance = FactoryBot.create(:models_instance, deployment: deployment, job: 'job', index: 1)
            disk = FactoryBot.create(:models_persistent_disk, disk_cid: 'disk1', instance: instance, active: true)
            FactoryBot.create(:models_snapshot, persistent_disk: disk, snapshot_cid: 'snap1a')
            FactoryBot.create(:models_snapshot, persistent_disk: disk, snapshot_cid: 'snap1b')
          end

          describe 'creating' do
            it 'should create a snapshot for a job' do
              post '/mycloud/jobs/job/1/snapshots'
              expect_redirect_to_queued_task(last_response)
            end

            it 'should create a snapshot for a deployment' do
              post '/mycloud/snapshots'
              expect_redirect_to_queued_task(last_response)
            end

            it 'should create a snapshot for a job and id' do
              post '/mycloud/jobs/job/abc123/snapshots'
              expect_redirect_to_queued_task(last_response)
            end
          end

          describe 'deleting' do
            it 'should delete all snapshots of a deployment' do
              delete '/mycloud/snapshots'
              expect_redirect_to_queued_task(last_response)
            end

            it 'should delete a snapshot' do
              delete '/mycloud/snapshots/snap1a'
              expect_redirect_to_queued_task(last_response)
            end

            it 'should raise an error if the snapshot belongs to a different deployment' do
              snap = FactoryBot.create(:models_snapshot, snapshot_cid: 'snap2b')
              delete "/#{snap.persistent_disk.instance.deployment.name}/snapshots/snap2a"
              expect(last_response.status).to eq(400)
            end
          end

          describe 'listing' do
            it 'should list all snapshots for a job' do
              get '/mycloud/jobs/job/0/snapshots'
              expect(last_response.status).to eq(200)
            end

            it 'should list all snapshots for a deployment' do
              get '/mycloud/snapshots'
              expect(last_response.status).to eq(200)
            end
          end
        end

        describe 'errands' do
          describe 'GET', '/:deployment_name/errands' do
            before { Config.base_dir = Dir.mktmpdir }
            after { FileUtils.rm_rf(Config.base_dir) }

            def perform
              get(
                '/fake-dep-name/errands',
                { 'CONTENT_TYPE' => 'application/json' },
              )
            end

            let(:cloud_config) { FactoryBot.create(:models_config_cloud, content: YAML.dump(SharedSupport::DeploymentManifestHelper.simple_cloud_config)) }

            let(:service_errand) do
              {
                'name' => 'service_errand_job',
                'jobs' => [{ 'name' => 'job_with_bin_run', 'release' => 'bosh-release' }],
                'lifecycle' => 'service',
                'vm_type' => 'a',
                'stemcell' => 'default',
                'instances' => 1,
                'networks' => [{ 'name' => 'a' }],
              }
            end

            let!(:deployment_model) do
              manifest_hash = manifest_with_errand_hash
              manifest_hash['instance_groups'] << service_errand
              model = FactoryBot.create(:models_deployment,
                name: 'fake-dep-name',
                manifest: YAML.dump(manifest_hash)
              )
              model.cloud_configs = [cloud_config]
              model
            end

            context 'authenticated access' do
              before do
                authorize 'admin', 'admin'
                deployment = FactoryBot.create(:models_deployment, name: 'errand')
                FactoryBot.create(:models_variable_set, deployment_id: deployment.id)
                release = FactoryBot.create(:models_release, name: 'bosh-release')
                template1 = FactoryBot.create(:models_template, name: 'foobar', release: release)
                template2 = FactoryBot.create(:models_template, name: 'errand1', release: release)
                template3 = FactoryBot.create(:models_template, name: 'job_with_bin_run', release: release, spec: {templates: {'foo' => 'bin/run'}})
                release_version = FactoryBot.create(:models_release_version, version: '0.1-dev', release: release)
                release_version.add_template(template1)
                release_version.add_template(template2)
                release_version.add_template(template3)
              end

              it 'returns errands in deployment' do
                expect(perform.body).to eq('[{"name":"fake-errand-name"},{"name":"another-errand"},{"name":"job_with_bin_run"}]')
                expect(last_response.status).to eq(200)
              end
            end

            context 'accessing with invalid credentials' do
              before { authorize 'invalid-user', 'invalid-password' }
              it 'returns 401' do
                perform
                expect(last_response.status).to eq(401)
              end
            end
          end

          describe 'POST', '/:deployment_name/errands/:name/runs' do
            before { Config.base_dir = Dir.mktmpdir }
            after { FileUtils.rm_rf(Config.base_dir) }

            let!(:deployment) { FactoryBot.create(:models_deployment, name: 'fake-dep-name')}

            def perform(post_body)
              post(
                '/fake-dep-name/errands/fake-errand-name/runs',
                JSON.dump(post_body),
                { 'CONTENT_TYPE' => 'application/json' },
              )
            end

            context 'authenticated access' do
              before { authorize 'admin', 'admin' }

              it 'returns a task' do
                perform({})
                expect_redirect_to_queued_task(last_response)
              end

              context 'running the errand' do
                let(:task) { instance_double('Bosh::Director::Models::Task', id: 1) }
                let(:job_queue) { instance_double('Bosh::Director::JobQueue', enqueue: task) }
                before { allow(JobQueue).to receive(:new).and_return(job_queue) }

                it 'enqueues a RunErrand task' do
                  expect(job_queue).to receive(:enqueue).with(
                    'admin',
                    Jobs::RunErrand,
                    'run errand fake-errand-name from deployment fake-dep-name',
                    ['fake-dep-name', 'fake-errand-name', false, false, []],
                    deployment,
                    ''
                  ).and_return(task)

                  perform({})
                end

                it 'sets context id on the RunErrand task' do
                  context_id = 'example-context-id'
                  expect(job_queue).to receive(:enqueue).with(
                    'admin',
                    Jobs::RunErrand,
                    'run errand fake-errand-name from deployment fake-dep-name',
                    ['fake-dep-name', 'fake-errand-name', false, false, []],
                    deployment,
                    context_id
                  ).and_return(task)

                  header('X-Bosh-Context-Id', context_id)
                  post(
                    '/fake-dep-name/errands/fake-errand-name/runs',
                    JSON.dump({}),
                    {
                      'CONTENT_TYPE' => 'application/json'
                    }
                  )
                end

                it 'enqueues a keep-alive task' do
                  expect(job_queue).to receive(:enqueue).with(
                    'admin',
                    Jobs::RunErrand,
                    'run errand fake-errand-name from deployment fake-dep-name',
                    ['fake-dep-name', 'fake-errand-name', true, false, []],
                    deployment,
                    ''
                  ).and_return(task)

                  perform({'keep-alive' => true})
                end

                it 'enqueues a when-changed task' do
                  expect(job_queue).to receive(:enqueue).with(
                    'admin',
                    Jobs::RunErrand,
                    'run errand fake-errand-name from deployment fake-dep-name',
                    ['fake-dep-name', 'fake-errand-name', false, true, []],
                    deployment,
                    ''
                  ).and_return(task)

                  perform({'when-changed' => true})
                end

                it 'enqueues a task to be run on select instances' do
                  expect(job_queue).to receive(:enqueue).with(
                    'admin',
                    Jobs::RunErrand,
                    'run errand fake-errand-name from deployment fake-dep-name',
                    ['fake-dep-name', 'fake-errand-name', false, false, ['group1/uuid1', 'group2/uuid2']],
                    deployment,
                    ''
                  ).and_return(task)

                  perform({'instances' => ['group1/uuid1', 'group2/uuid2']})
                end
              end
            end

            context 'accessing with invalid credentials' do
              before { authorize 'invalid-user', 'invalid-password' }

              it 'returns 401' do
                perform({})
                expect(last_response.status).to eq(401)
              end
            end
          end
        end

        describe 'diff' do
          def perform
            post(
              '/fake-dep-name/diff',
              "---\nname: fake-dep-name\nreleases: [{'name':'simple','version':5}]",
              { 'CONTENT_TYPE' => 'text/yaml' },
            )
          end
          let(:runtime_config_1) { FactoryBot.create(:models_config_runtime, raw_manifest: {'addons' => []}) }
          let(:runtime_config_2) { FactoryBot.create(:models_config_runtime, raw_manifest: {'addons' => []}) }
          let(:runtime_config_3) { FactoryBot.create(:models_config_runtime, raw_manifest: {'addons' => []}, name: 'smurf') }
          let(:cloud_config) { FactoryBot.create(:models_config_cloud, raw_manifest: {'azs' => []}) }

          before do
            deployment = Models::Deployment.create(
              name: 'fake-dep-name',
              manifest: YAML.dump({ 'instance_groups' => [], 'releases' => [{ 'name' => 'simple', 'version' => 5 }] })
            )
            deployment.cloud_configs = [cloud_config]
            deployment.runtime_configs = [runtime_config_1, runtime_config_2, runtime_config_3]
          end

          context 'authenticated access' do
            before { authorize 'admin', 'admin' }

            let(:manifest_hash) do
              { 'instance_groups' => [], 'releases' => [{ 'name' => 'simple', 'version' => 5 }] }
            end

            let(:dev_team) { FactoryBot.create(:models_team, name: 'dev') }
            let(:other_team) { FactoryBot.create(:models_team, name: 'other') }

            let!(:dev_runtime_config) { FactoryBot.create(:models_config_runtime, name: 'dev-runtime', team_id: dev_team.id) }
            let!(:other_runtime_config) { FactoryBot.create(:models_config_runtime, name: 'other-runtime', team_id: other_team.id) }

            let!(:dev_cloud_config) { FactoryBot.create(:models_config_cloud, name: 'dev-cloud', team_id: dev_team.id) }
            let!(:other_cloud_config) { FactoryBot.create(:models_config_cloud, name: 'other-cloud', team_id: other_team.id) }

            it 'returns diff with resolved aliases' do
              perform

              body = JSON.parse(last_response.body)
              expect(body['context']).to_not be_nil
              expect(body['context']['cloud_config_ids']).to contain_exactly(cloud_config.id)
              expect(body['context']['runtime_config_ids']).to contain_exactly(
                runtime_config_2.id,
                runtime_config_3.id,
              )
              expect(body['diff']).to eq([['instance_groups: []', 'removed'], ['', nil], ['name: fake-dep-name', 'added']])
            end

            it 'gives a nice error when request body is not a valid yml' do
              post '/fake-dep-name/diff', "}}}i'm not really yaml, hah!", {'CONTENT_TYPE' => 'text/yaml'}

              expect(last_response.status).to eq(200)
              expect(JSON.parse(last_response.body)['error']).to include('Unable to diff manifest: ')
              expect(JSON.parse(last_response.body)['error']).to include('Incorrect YAML structure of the uploaded manifest: ' )
            end

            it 'gives a nice error when request body is empty' do
              post '/fake-dep-name/diff', '', {'CONTENT_TYPE' => 'text/yaml'}

              expect(last_response.status).to eq(200)
              expect(JSON.parse(last_response.body)['error']).to include('Unable to diff manifest: ')
              expect(JSON.parse(last_response.body)['error']).to include('Manifest should not be empty' )
            end

            it 'returns 200 with an empty diff and an error message if the diffing fails' do
              allow(Bosh::Director::Manifest).to receive_message_chain(:load_from_model, :resolve_aliases)
              allow(Bosh::Director::Manifest).to receive_message_chain(:load_from_model, :diff).and_raise('Oooooh crap')

              post '/fake-dep-name/diff', {}.to_yaml, {'CONTENT_TYPE' => 'text/yaml'}

              expect(last_response.status).to eq(200)
              expect(JSON.parse(last_response.body)['diff']).to eq([])
              expect(JSON.parse(last_response.body)['error']).to include('Unable to diff manifest')
            end

            context 'existing deployment' do
              let(:deployment) do
                FactoryBot.create(:models_deployment, name: 'existing-name', manifest: '{}').tap { |d| d.teams = [dev_team] }
              end

              it 'provides team-specific runtime and cloud configs in context' do
                response = post "/#{deployment.name}/diff", YAML.dump(manifest_hash), {'CONTENT_TYPE' => 'text/yaml'}
                expect(response.status).to eq(200)

                diff = JSON.parse(response.body)

                expect(diff['context']['cloud_config_ids']).to contain_exactly(dev_cloud_config.id, cloud_config.id)
                expect(diff['context']['runtime_config_ids']).to contain_exactly(
                  dev_runtime_config.id,
                  runtime_config_2.id,
                  runtime_config_3.id,
                )
              end
            end

            context 'team-specific for non-existent deployment' do
              before { basic_authorize 'dev-team-member', 'dev-team-member' }

              it 'provides team-specific runtime and cloud configs in context' do
                response = post '/fake-dep-name-no-cloud-conf/diff', YAML.dump(manifest_hash), {'CONTENT_TYPE' => 'text/yaml'}
                expect(response.status).to eq(200)

                diff = JSON.parse(response.body)

                expect(diff['context']['cloud_config_ids']).to contain_exactly(dev_cloud_config.id, cloud_config.id)
                expect(diff['context']['runtime_config_ids']).to contain_exactly(
                  dev_runtime_config.id,
                  runtime_config_2.id,
                  runtime_config_3.id,
                )
              end
            end
          end

          context 'accessing with invalid credentials' do
            before { authorize 'invalid-user', 'invalid-password' }

            it 'returns 401' do
              perform
              expect(last_response.status).to eq(401)
            end
          end
        end

        describe 'variables' do
          let(:deployment_manifest) { { 'name' => 'test_deployment' } }
          let!(:deployment) { FactoryBot.create(:models_deployment, name: 'test_deployment', manifest: deployment_manifest.to_yaml) }
          let!(:variable_set) { FactoryBot.create(:models_variable_set, id: 1, deployment: deployment) }

          before do
            basic_authorize 'admin', 'admin'
          end

          it 'returns an empty array if there are no variables' do
            get '/test_deployment/variables'
            expect(last_response.status).to eq(200)
            vars = JSON.parse(last_response.body)
            expect(vars).to be_empty
          end

          context 'when a deployment has variables' do
            let(:deployment_manifest) do
              {
                'name' => 'test_deployment',
                'variables' => [
                  { 'name' => 'var_name_1' },
                  { 'name' => 'var_name_2' },
                ],
              }
            end

            before do
              FactoryBot.create(:models_variable,
                id: 1,
                variable_id: 'var_id_1',
                variable_name: '/Test Director/test_deployment/var_name_1',
                variable_set_id: variable_set.id,
              )
              FactoryBot.create(:models_variable,
                id: 2,
                variable_id: 'var_id_2',
                variable_name: '/Test Director/test_deployment/var_name_2',
                variable_set_id: variable_set.id,
              )
            end

            it 'returns a unique list of variable ids and names' do
              get '/test_deployment/variables'
              expect(last_response.status).to eq(200)
              vars = JSON.parse(last_response.body)
              expect(vars).to match_array(
                [
                  { 'id' => 'var_id_1', 'name' => '/Test Director/test_deployment/var_name_1' },
                  { 'id' => 'var_id_2', 'name' => '/Test Director/test_deployment/var_name_2' },
                ],
              )
            end
          end
        end
      end

      describe 'authorization' do
        before do
          release = FactoryBot.create(:models_release, name: 'bosh-release')
          template1 = FactoryBot.create(:models_template, name: 'foobar', release: release)
          template2 = FactoryBot.create(:models_template, name: 'errand1', release: release)
          release_version = FactoryBot.create(:models_release_version, version: '0.1-dev', release: release)
          release_version.add_template(template1)
          release_version.add_template(template2)
        end

        let(:dev_team) { Models::Team.create(name: 'dev') }
        let(:other_team) { Models::Team.create(name: 'other') }
        let!(:owned_deployment) { Models::Deployment.create_with_teams(name: 'owned_deployment', teams: [dev_team], manifest: manifest_with_errand('owned_deployment'), cloud_configs: [cloud_config]) }
        let!(:other_deployment) { Models::Deployment.create_with_teams(name: 'other_deployment', teams: [other_team], manifest: manifest_with_errand('other_deployment'), cloud_configs: [cloud_config]) }
        describe 'when a user has dev team admin membership' do

          before {
            instance = Models::Instance.create(deployment: owned_deployment, job: 'dea', index: 0, state: :started, uuid: 'F0753566-CA8E-4B28-AD63-7DB3903CD98C', variable_set: Models::VariableSet.create(deployment: owned_deployment))
            Models::Instance.create(deployment: other_deployment, job: 'dea', index: 0, state: :started, uuid: '72652FAA-1A9C-4803-8423-BBC3630E49C6', variable_set: Models::VariableSet.create(deployment: other_deployment))
            FactoryBot.create(:models_vm, agent_id: 'random-id', instance_id: instance.id, active: true)
          }

          # dev-team-member has scopes ['bosh.teams.dev.admin']
          before { basic_authorize 'dev-team-member', 'dev-team-member' }

          context 'GET /:deployment/jobs/:job/:index_or_id' do
            it 'allows access to owned deployment' do
              expect(get('/owned_deployment/jobs/dea/0').status).to eq(200)
            end

            it 'denies access to other deployment' do
              expect(get('/other_deployment/jobs/dea/0').status).to eq(401)
            end
          end

          context 'PUT /:deployment/jobs/:job' do
            it 'allows access to owned deployment' do
              expect(put('/owned_deployment/jobs/dea?state=running', nil, { 'CONTENT_TYPE' => 'text/yaml' }).status).to eq(302)
            end

            it 'denies access to other deployment' do
              expect(put('/other_deployment/jobs/dea?state=running', nil, { 'CONTENT_TYPE' => 'text/yaml' }).status).to eq(401)
            end
          end

          context 'PUT /:deployment/jobs/:job/:index_or_id' do
            it 'allows access to owned deployment' do
              expect(put('/owned_deployment/jobs/dea/0', nil, { 'CONTENT_TYPE' => 'text/yaml' }).status).to eq(302)
            end

            it 'denies access to other deployment' do
              expect(put('/other_deployment/jobs/dea/0', nil, { 'CONTENT_TYPE' => 'text/yaml' }).status).to eq(401)
            end
          end

          context 'GET /:deployment/jobs/:job/:index_or_id/logs' do
            it 'allows access to owned deployment' do
              expect(get('/owned_deployment/jobs/dea/0/logs').status).to eq(302)
            end
            it 'denies access to other deployment' do
              expect(get('/other_deployment/jobs/dea/0/logs').status).to eq(401)
            end
          end

          context 'GET /:deployment/snapshots' do
            it 'allows access to owned deployment' do
              expect(get('/owned_deployment/snapshots').status).to eq(200)
            end
            it 'denies access to other deployment' do
              expect(get('/other_deployment/snapshots').status).to eq(401)
            end
          end

          context 'GET /:deployment/jobs/:job/:index/snapshots' do
            it 'allows access to owned deployment' do
              expect(get('/owned_deployment/jobs/dea/0/snapshots').status).to eq(200)
            end
            it 'denies access to other deployment' do
              expect(get('/other_deployment/jobs/dea/0/snapshots').status).to eq(401)
            end
          end

          context 'POST /:deployment/snapshots' do
            it 'allows access to owned deployment' do
              expect(post('/owned_deployment/snapshots').status).to eq(302)
            end
            it 'denies access to other deployment' do
              expect(post('/other_deployment/snapshots').status).to eq(401)
            end
          end

          context 'PUT /:deployment/jobs/:job/:index_or_id/resurrection' do
            it 'allows access to owned deployment' do
              put('/owned_deployment/jobs/dea/0/resurrection', '{}', 'CONTENT_TYPE' => 'application/json')

              expect(last_response.status).to eq(410)
              expect(last_response.body).to include(
                'This endpoint has been removed. Please use '\
                  'https://bosh.io/docs/resurrector/#enable-with-resurrection-config to configure resurrection for the '\
                  'deployment or instance group. If you need to prevent a single instance from being resurrected, '\
                  'consider using https://bosh.io/docs/cli-v2/#ignore.',
              )
            end
            it 'denies access to other deployment' do
              expect(put('/other_deployment/jobs/dea/0/resurrection', '{}', { 'CONTENT_TYPE' => 'application/json' }).status).to eq(401)
            end
          end

          context 'PUT /:deployment/instance_groups/:instancegroup/:id/ignore' do
            it 'allows access to owned deployment via instance id' do
              expect(put('/owned_deployment/instance_groups/dea/F0753566-CA8E-4B28-AD63-7DB3903CD98C/ignore', '{}', { 'CONTENT_TYPE' => 'application/json' }).status).to eq(200)
            end

            it 'allows access to owned deployment via vm index' do
              expect(put('/owned_deployment/instance_groups/dea/0/ignore', '{}', { 'CONTENT_TYPE' => 'application/json' }).status).to eq(200)
            end

            it 'denies access to other deployment' do
              expect(put('/other_deployment/instance_groups/dea/72652FAA-1A9C-4803-8423-BBC3630E49C6/ignore', '{}', { 'CONTENT_TYPE' => 'application/json' }).status).to eq(401)
            end
          end

          context 'POST /:deployment/jobs/:job/:index_or_id/snapshots' do
            it 'allows access to owned deployment' do
              expect(post('/owned_deployment/jobs/dea/0/snapshots').status).to eq(302)
            end

            it 'denies access to other deployment' do
              expect(post('/other_deployment/jobs/dea/0/snapshots').status).to eq(401)
            end
          end

          context 'DELETE /:deployment/snapshots' do
            it 'allows access to owned deployment' do
              expect(delete('/owned_deployment/snapshots').status).to eq(302)
            end

            it 'denies access to other deployment' do
              expect(delete('/other_deployment/snapshots').status).to eq(401)
            end
          end

          context 'DELETE /:deployment/snapshots/:cid' do
            before do
              instance = FactoryBot.create(:models_instance, deployment: owned_deployment)
              persistent_disk = FactoryBot.create(:models_persistent_disk, instance: instance)
              FactoryBot.create(:models_snapshot, persistent_disk: persistent_disk, snapshot_cid: 'cid-1')
            end

            it 'allows access to owned deployment' do
              expect(delete('/owned_deployment/snapshots/cid-1').status).to eq(302)
            end

            it 'denies access to other deployment' do
              expect(delete('/other_deployment/snapshots/cid-1').status).to eq(401)
            end
          end

          context 'GET /:deployment' do
            it 'allows access to owned deployment' do
              expect(get('/owned_deployment').status).to eq(200)
            end

            it 'denies access to other deployment' do
              expect(get('/other_deployment').status).to eq(401)
            end
          end

          context 'GET /:deployment/vms' do
            it 'allows access to owned deployment' do
              expect(get('/owned_deployment/vms').status).to eq(200)
            end

            it 'denies access to other deployment' do
              expect(get('/other_deployment/vms').status).to eq(401)
            end
          end

          context 'DELETE /:deployment' do
            it 'allows access to owned deployment' do
              expect(delete('/owned_deployment').status).to eq(302)
            end

            it 'denies access to other deployment' do
              expect(delete('/other_deployment').status).to eq(401)
            end
          end

          context 'POST /:deployment/ssh' do
            it 'allows access to owned deployment' do
              expect(post('/owned_deployment/ssh', '{}', { 'CONTENT_TYPE' => 'application/json' }).status).to eq(302)
            end

            it 'denies access to other deployment' do
              expect(post('/other_deployment/ssh', '{}', { 'CONTENT_TYPE' => 'application/json' }).status).to eq(401)
            end
          end

          context 'POST /:deployment/scans' do
            it 'allows access to owned deployment' do
              expect(post('/owned_deployment/scans').status).to eq(302)
            end

            it 'denies access to other deployment' do
              expect(post('/other_deployment/scans').status).to eq(401)
            end
          end

          context 'GET /:deployment/problems' do
            it 'allows access to owned deployment' do
              expect(get('/owned_deployment/problems').status).to eq(200)
            end

            it 'denies access to other deployment' do
              expect(get('/other_deployment/problems').status).to eq(401)
            end
          end

          context 'PUT /:deployment/problems' do
            it 'allows access to owned deployment' do
              expect(put('/owned_deployment/problems', '{"resolutions": {}}', { 'CONTENT_TYPE' => 'application/json' }).status).to eq(302)
            end

            it 'denies access to other deployment' do
              expect(put('/other_deployment/problems', '', { 'CONTENT_TYPE' => 'application/json' }).status).to eq(401)
            end
          end

          context 'PUT /:deployment/problems' do
            it 'allows access to owned deployment' do
              expect(put('/owned_deployment/problems', '{"resolutions": {}}', { 'CONTENT_TYPE' => 'application/json' }).status).to eq(302)
            end

            it 'denies access to other deployment' do
              expect(put('/other_deployment/problems', '{"resolutions": {}}', { 'CONTENT_TYPE' => 'application/json' }).status).to eq(401)
            end
          end

          context 'PUT /:deployment/scan_and_fix' do
            it 'allows access to owned deployment' do
              expect(put('/owned_deployment/scan_and_fix', '{"jobs": []}', { 'CONTENT_TYPE' => 'application/json' }).status).to eq(302)
            end

            it 'denies access to other deployment' do
              expect(put('/other_deployment/scan_and_fix', '{"jobs": []}', { 'CONTENT_TYPE' => 'application/json' }).status).to eq(401)
            end
          end

          describe 'POST /' do
            it 'allows' do
              expect(post('/', manifest_with_errand, { 'CONTENT_TYPE' => 'text/yaml' }).status).to eq(302)
            end
          end

          context 'POST /:deployment/diff' do
            it 'allows access to new deployment' do
              expect(post('/new_deployment/diff', '{}', { 'CONTENT_TYPE' => 'text/yaml' }).status).to eq(200)
            end

            it 'allows access to owned deployment' do
              expect(post('/owned_deployment/diff', '{}', { 'CONTENT_TYPE' => 'text/yaml' }).status).to eq(200)
            end

            it 'denies access to other deployment' do
              expect(post('/other_deployment/diff', '{}', { 'CONTENT_TYPE' => 'text/yaml' }).status).to eq(401)
            end
          end

          context 'POST /:deployment/errands/:errand_name/runs' do
            it 'allows access to owned deployment' do
              expect(post('/owned_deployment/errands/errand_job/runs', '{}', { 'CONTENT_TYPE' => 'application/json' }).status).to eq(302)
            end

            it 'denies access to other deployment' do
              expect(post('/other_deployment/errands/errand_job/runs', '{}', { 'CONTENT_TYPE' => 'application/json' }).status).to eq(401)
            end
          end

          context 'GET /:deployment/errands' do

            let(:cloud_config) { FactoryBot.create(:models_config_cloud, content: YAML.dump(SharedSupport::DeploymentManifestHelper.simple_cloud_config)) }

            it 'allows access to owned deployment' do
              expect(get('/owned_deployment/errands').status).to eq(200)
            end

            it 'denies access to other deployment' do
              expect(get('/other_deployment/errands').status).to eq(401)
            end
          end

          context 'GET /' do
            it 'allows access to owned deployments' do
              response = get('/')
              expect(response.status).to eq(200)
              expect(response.body).to include('"owned_deployment"')
              expect(response.body).to_not include('"other_deployment"')
            end
          end
        end

        describe 'when the user has bosh.read scope' do
          describe 'read endpoints' do
            before { basic_authorize 'reader', 'reader' }

            it 'allows access' do
              expect(get('/',).status).to eq(200)
              expect(get('/owned_deployment').status).to eq(200)
              expect(get('/owned_deployment/vms').status).to eq(200)
              expect(get('/no_deployment/errands').status).to eq(404)
            end
          end
        end
      end

      describe 'when the user merely has team read scope' do
        before { basic_authorize 'dev-team-read-member', 'dev-team-read-member' }
        it 'denies access to POST /' do
          expect(post('/', '{}', { 'CONTENT_TYPE' => 'text/yaml' }).status).to eq(401)
        end
      end
    end
  end
end
