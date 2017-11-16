require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::DeploymentsController do
      include IpUtil
      include Rack::Test::Methods

      subject(:app) { linted_rack_app(described_class.new(config)) }

      let(:config) do
        config = Config.load_hash(SpecHelper.spec_get_director_config)
        identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
        allow(config).to receive(:identity_provider).and_return(identity_provider)
        config
      end

      def manifest_with_errand_hash(deployment_name='errand')
        manifest_hash = Bosh::Spec::NewDeployments.manifest_with_errand
        manifest_hash['name'] = deployment_name
        manifest_hash['instance_groups'] << {
          'name' => 'another-errand',
          'jobs' => [{'name' => 'errand1'}],
          'stemcell' => 'default',
          'lifecycle' => 'errand',
          'vm_type' => 'a',
          'instances' => 1,
          'networks' => [{'name' => 'a'}]
        }
        manifest_hash
      end

      def manifest_with_errand(deployment_name='errand')
        YAML.dump(manifest_with_errand_hash(deployment_name))
      end

      let(:cloud_config) { Models::Config.make(:cloud_with_manifest) }
      let (:time) {Time.now}
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
              post '/', spec_asset('test_conf.yaml'), {'CONTENT_TYPE' => 'text/yaml'}
              expect_redirect_to_queued_task(last_response)
            end

            it 'accepts a context ID header' do
              context_id = 'example-context-id'
              header('X-Bosh-Context-Id', context_id)
              post '/', spec_asset('test_conf.yaml'), {'CONTENT_TYPE' => 'text/yaml'}
              task = expect_redirect_to_queued_task(last_response)
              expect(task.context_id).to eq(context_id)
            end

            it 'defaults to no context ID' do
              post '/', spec_asset('test_conf.yaml'), {'CONTENT_TYPE' => 'text/yaml'}
              task = expect_redirect_to_queued_task(last_response)
              expect(task.context_id).to eq('')
            end

            it 'only consumes text/yaml' do
              post '/', spec_asset('test_conf.yaml'), {'CONTENT_TYPE' => 'text/plain'}
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

            context 'when provided a cloud config and runtime config context to work within' do
              it 'should use the provided context instead of using the latest runtime and cloud config' do
                cloud_config = Models::Config.make(:cloud_with_manifest)
                runtime_config_1 = Models::Config.make(type: 'runtime')
                runtime_config_2 = Models::Config.make(type: 'runtime')

                Models::Config.make(:cloud_with_manifest)
                Models::Config.make(type: 'runtime')

                deployment_context = [['context', JSON.dump({'cloud_config_ids' => [cloud_config.id], 'runtime_config_ids' => [runtime_config_1.id, runtime_config_2.id]})]]

                allow_any_instance_of(DeploymentManager)
                  .to receive(:create_deployment)
                  .with(anything, anything, [cloud_config], [runtime_config_1, runtime_config_2], anything, anything, anything)
                  .and_return(Models::Task.make)

                post "/?#{URI.encode_www_form(deployment_context)}", spec_asset('test_conf.yaml'), {'CONTENT_TYPE' => 'text/yaml'}

                expect_redirect_to_queued_task(last_response)
              end
            end

            context 'when using cloud config and runtime config' do
              it 'should persist these relations when persisting the deployment' do
                cloud_config = Models::Config.make(:cloud_with_manifest)
                runtime_config = Models::Config.make(type: 'runtime')

                post '/', spec_asset('test_conf.yaml'), {'CONTENT_TYPE' => 'text/yaml'}

                expect_redirect_to_queued_task(last_response)
                deployment = Models::Deployment.first
                expect(deployment.cloud_configs).to contain_exactly(cloud_config)
                expect(deployment.runtime_configs).to contain_exactly(runtime_config)
              end
            end

            context 'when doing a deploy with dry-run' do
              it 'should queue a dry run task' do
                expect(Models::Task.all).to be_empty

                post '/?dry_run=true', spec_asset('test_conf.yaml'), {'CONTENT_TYPE' => 'text/yaml'}

                expect_redirect_to_queued_task(last_response)

                expect(Models::Task.count).to eq(1)
                expect(Models::Task.first.description).to eq('create deployment (dry run)')
              end
            end
          end

          context 'accessing with invalid credentials' do
            before { authorize 'invalid-user', 'invalid-password' }

            it 'returns 401' do
              post '/', spec_asset('test_conf.yaml'), {'CONTENT_TYPE' => 'text/yaml'}
              expect(last_response.status).to eq(401)
            end
          end
        end

        describe 'updating a deployment' do
          let!(:deployment) { Models::Deployment.create(:name => 'my-test-deployment', :manifest => YAML.dump({'foo' => 'bar'})) }

          context 'without the "skip_drain" param' do
            it 'does not skip draining' do
              allow_any_instance_of(DeploymentManager)
                .to receive(:create_deployment)
                .with(anything(), anything(), anything(), anything(), anything(), hash_excluding('skip_drain'), anything())
                .and_return(OpenStruct.new(:id => 1))
              post '/', spec_asset('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml' }
              expect(last_response).to be_redirect
            end
          end

          context 'with the "skip_drain" param as "*"' do
            it 'skips draining' do
              allow_any_instance_of(DeploymentManager)
                .to receive(:create_deployment)
                .with(anything(), anything(), anything(), anything(), anything(), hash_including('skip_drain' => '*'),  anything())
                .and_return(OpenStruct.new(:id => 1))
              post '/?skip_drain=*', spec_asset('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml' }
              expect(last_response).to be_redirect
            end
          end

          context 'with the "skip_drain" param as "job_one,job_two"' do
            it 'skips draining' do
              expect_any_instance_of(DeploymentManager)
                .to receive(:create_deployment)
                .with(anything(), anything(), anything(), anything(), anything(), hash_including('skip_drain' => 'job_one,job_two'), anything())
                .and_return(OpenStruct.new(:id => 1))
              post '/?skip_drain=job_one,job_two', spec_asset('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml' }
              expect(last_response).to be_redirect
            end
          end

          context 'with the "fix" param' do
            it 'passes the parameter' do
              allow_any_instance_of(DeploymentManager)
                .to receive(:create_deployment)
                .with(anything(), anything(), anything(), anything(), anything(), hash_including('fix' => true), anything())
                .and_return(OpenStruct.new(:id => 1))
              post '/?fix=true', spec_asset('test_conf.yaml'), {'CONTENT_TYPE' => 'text/yaml'}
              expect(last_response).to be_redirect
            end
          end

          context 'updates using a manifest with deployment name' do
            it 'calls create deployment with deployment name' do
              expect_any_instance_of(DeploymentManager)
                  .to receive(:create_deployment)
                          .with(anything(), anything(), anything(), anything(), deployment, hash_excluding('skip_drain'), anything())
                          .and_return(OpenStruct.new(:id => 1))
              post '/', spec_asset('test_manifest.yml'), { 'CONTENT_TYPE' => 'text/yaml' }
              expect(last_response).to be_redirect
            end
          end

          context 'sets `new` option' do
            it 'to false' do
              expect_any_instance_of(DeploymentManager)
                  .to receive(:create_deployment)
                          .with(anything(), anything(), anything(), anything(), deployment, hash_including('new' => false), anything())
                          .and_return(OpenStruct.new(:id => 1))
              post '/', spec_asset('test_manifest.yml'), { 'CONTENT_TYPE' => 'text/yaml' }
            end

            it 'to true' do
              expect_any_instance_of(DeploymentManager)
                  .to receive(:create_deployment)
                          .with(anything(), anything(), anything(), anything(), anything(), hash_including('new' => true), anything())
                          .and_return(OpenStruct.new(:id => 1))
               Models::Deployment.first.delete
              post '/', spec_asset('test_manifest.yml'), { 'CONTENT_TYPE' => 'text/yaml' }
            end
          end
        end

        describe 'deleting deployment' do
          it 'deletes the deployment' do
            deployment = Models::Deployment.create(:name => 'test_deployment', :manifest => YAML.dump({'foo' => 'bar'}))

            delete '/test_deployment'
            expect_redirect_to_queued_task(last_response)
          end

          it 'accepts a context id' do
            context_id = 'example-context-id'
            deployment = Models::Deployment.create(:name => 'test_deployment', :manifest => YAML.dump({'foo' => 'bar'}))

            header('X-Bosh-Context-Id', context_id)
            delete '/test_deployment'

            task = expect_redirect_to_queued_task(last_response)
            expect(task.context_id).to eq(context_id)
          end
        end

        describe 'job management' do
          shared_examples 'change state' do
            it 'allows to change state' do
              deployment = Models::Deployment.create(name: 'foo', manifest: YAML.dump({'foo' => 'bar'}))
              instance = Models::Instance.create(
                deployment: deployment,
                job: 'dea',
                index: '2',
                uuid: '0B949287-CDED-4761-9002-FC4035E11B21',
                state: 'started',
                :variable_set => Models::VariableSet.create(deployment: deployment)
              )
              Models::PersistentDisk.create(instance: instance, disk_cid: 'disk_cid')
              put "#{path}", spec_asset('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml' }
              expect_redirect_to_queued_task(last_response)
            end

            it 'allows to change state with content_length of 0' do
              RSpec::Matchers.define :not_to_have_body do |unexpected|
                match { |actual| actual != unexpected }
              end
              manifest = spec_asset('test_conf.yaml')
              allow_any_instance_of(DeploymentManager).to receive(:create_deployment).
                  with(anything(), not_to_have_body(manifest), anything(), anything(), anything(), anything()).
                  and_return(OpenStruct.new(:id => 'no_content_length'))
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
              put "#{path}", spec_asset('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml' }
              expect(last_response.status).to eq(404)
            end
          end

          context 'for all jobs in deployment' do
            let (:path) { '/foo/jobs/*?state=stopped' }
            it_behaves_like 'change state'
          end
          context 'for one job in deployment' do
            let (:path) { '/foo/jobs/dea?state=stopped' }
            it_behaves_like 'change state'
          end
          context 'for job instance in deployment by index' do
            let (:path) { '/foo/jobs/dea/2?state=stopped' }
            it_behaves_like 'change state'
          end
          context 'for job instance in deployment by id' do
            let (:path) { '/foo/jobs/dea/0B949287-CDED-4761-9002-FC4035E11B21?state=stopped' }
            it_behaves_like 'change state'
          end

          let(:deployment) do
            Models::Deployment.create(name: 'foo', manifest: YAML.dump({'foo' => 'bar'}))
          end

          it 'allows putting the job instance into different resurrection_paused values' do
            instance = Models::Instance.
                create(:deployment => deployment, :job => 'dea',
                       :index => '0', :state => 'started', :variable_set => Models::VariableSet.create(deployment: deployment))
            put '/foo/jobs/dea/0/resurrection', JSON.generate('resurrection_paused' => true), { 'CONTENT_TYPE' => 'application/json' }
            expect(last_response.status).to eq(200)
            expect(instance.reload.resurrection_paused).to be(true)
          end

          it 'allows putting the job instance into different ignore state' do
            instance = Models::Instance.
                create(:deployment => deployment, :job => 'dea',
                       :index => '0', :state => 'started', :uuid => '0B949287-CDED-4761-9002-FC4035E11B21',
                       :variable_set => Models::VariableSet.create(deployment: deployment))
            expect(instance.ignore).to be(false)
            put '/foo/instance_groups/dea/0B949287-CDED-4761-9002-FC4035E11B21/ignore', JSON.generate('ignore' => true), { 'CONTENT_TYPE' => 'application/json' }
            expect(last_response.status).to eq(200)
            expect(instance.reload.ignore).to be(true)

            put '/foo/instance_groups/dea/0B949287-CDED-4761-9002-FC4035E11B21/ignore', JSON.generate('ignore' => false), { 'CONTENT_TYPE' => 'application/json' }
            expect(last_response.status).to eq(200)
            expect(instance.reload.ignore).to be(false)
          end

          it 'gives a nice error when uploading non valid manifest' do
            instance = Models::Instance.
                create(:deployment => deployment, :job => 'dea',
                       :index => '0', :state => 'started', :variable_set => Models::VariableSet.create(deployment: deployment))

            put '/foo/jobs/dea', "}}}i'm not really yaml, hah!", {'CONTENT_TYPE' => 'text/yaml'}

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['code']).to eq(440001)
            expect(JSON.parse(last_response.body)['description']).to include('Incorrect YAML structure of the uploaded manifest: ')
          end

          it 'should not validate body content when content.length is zero' do
            Models::Instance.
                create(:deployment => deployment, :job => 'dea',
                       :index => '0', :state => 'started', :variable_set => Models::VariableSet.create(deployment: deployment))

            put '/foo/jobs/dea/0?state=started', "}}}i'm not really yaml, hah!", {'CONTENT_TYPE' => 'text/yaml', 'CONTENT_LENGTH' => '0'}

            expect(last_response.status).to eq(302)
          end

          it 'returns a "bad request" if index_or_id parameter of a PUT is neither a number nor a string with uuid format' do
            deployment
            put '/foo/jobs/dea/snoopy?state=stopped', spec_asset('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml' }
            expect(last_response.status).to eq(400)
          end

          it 'can get job information' do
            instance = Models::Instance.create(
              deployment: deployment,
              job: 'nats',
              index: '0',
              uuid: 'fake_uuid',
              state: 'started',
              :variable_set => Models::VariableSet.create(deployment: deployment)
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
                  .with(anything(), anything(), anything(), anything(), anything(), hash_including('canaries'=>'42') )
                  .and_return(OpenStruct.new(:id => 1))

              put '/foo/jobs/dea?canaries=42', JSON.generate('value' => 'baz'), { 'CONTENT_TYPE' => 'text/yaml' }
              expect(last_response).to be_redirect
            end
          end

          context 'with a "max_in_flight" param' do
            it 'overrides the "max_in_flight" value from the manifest' do
              deployment
              expect_any_instance_of(DeploymentManager)
                .to receive(:create_deployment)
                      .with(anything(), anything(), anything(), anything(), anything(), hash_including('max_in_flight'=>'42') )
                      .and_return(OpenStruct.new(:id => 1))

              put '/foo/jobs/dea?max_in_flight=42', JSON.generate('value' => 'baz'), { 'CONTENT_TYPE' => 'text/yaml' }
              expect(last_response).to be_redirect
            end
          end

          context 'with a "fix" param' do
            it 'passes the parameter' do
              deployment
              expect_any_instance_of(DeploymentManager)
                .to receive(:create_deployment)
                .with(anything(), anything(), anything(), anything(), anything(), hash_including('fix' => true))
                .and_return(OpenStruct.new(:id => 1))

              put '/foo/jobs/dea?fix=true', JSON.generate('value' => 'baz'), {'CONTENT_TYPE' => 'text/yaml'}
              expect(last_response).to be_redirect
            end
          end

        describe 'recreating' do
          shared_examples_for "recreates with configs" do
            it 'recreates with the latest configs if you send a manifest' do
              cc_old = Models::Config.create(:name => 'cc', :type =>'cloud', :content => YAML.dump({'foo' => 'old-cc'}))
              cc_new = Models::Config.create(:name => 'cc', :type =>'cloud', :content => YAML.dump({'foo' => 'new-cc'}))
              runtime_old = Models::Config.create(:name => 'runtime', :type =>'runtime', :content => YAML.dump({'foo' => 'old-runtime'}))
              runtime_new = Models::Config.create(:name => 'runtime', :type =>'runtime', :content => YAML.dump({'foo' => 'new-runtime'}))

              deployment = Models::Deployment.create(name: 'foo', manifest: YAML.dump({'foo' => 'bar'}))
              deployment.cloud_configs = [cc_old]
              deployment.runtime_configs = [runtime_old]

              instance = Models::Instance.create(
                deployment: deployment,
                job: 'dea',
                index: '2',
                uuid: '0B949287-CDED-4761-9002-FC4035E11B21',
                state: 'started',
                :variable_set => Models::VariableSet.create(deployment: deployment)
              )
              expect_any_instance_of(DeploymentManager)
                  .to receive(:create_deployment)
                          .with(anything(), anything(), [cc_new], [runtime_new], deployment, hash_including(options))
                          .and_return(OpenStruct.new(:id => 1))
              put "#{path}", JSON.generate('value' => 'baz'), {'CONTENT_TYPE' => 'text/yaml'}
              expect(last_response).to be_redirect
            end

            it 'recreates with the previous configs rather than the latest' do
              cc_old = Models::Config.create(:name => 'cc', :type =>'cloud', :content => YAML.dump({'foo' => 'old-cc'}))
              cc_new = Models::Config.create(:name => 'cc', :type =>'cloud', :content => YAML.dump({'foo' => 'new-cc'}))
              runtime_old = Models::Config.create(:name => 'runtime', :type =>'runtime', :content => YAML.dump({'foo' => 'old-runtime'}))
              runtime_new = Models::Config.create(:name => 'runtime', :type =>'runtime', :content => YAML.dump({'foo' => 'new-runtime'}))

              deployment = Models::Deployment.create(name: 'foo', manifest: YAML.dump({'foo' => 'bar'}))
              deployment.cloud_configs = [cc_old]
              deployment.runtime_configs = [runtime_old]

              instance = Models::Instance.create(
                deployment: deployment,
                job: 'dea',
                index: '2',
                uuid: '0B949287-CDED-4761-9002-FC4035E11B21',
                state: 'started',
                :variable_set => Models::VariableSet.create(deployment: deployment)
              )
              expect_any_instance_of(DeploymentManager)
                  .to receive(:create_deployment)
                          .with(anything(), anything(), [cc_old], [runtime_old], deployment, hash_including(options))
                          .and_return(OpenStruct.new(:id => 1))
              put "#{path}", '', {'CONTENT_TYPE' => 'text/yaml'}
              expect(last_response).to be_redirect
            end
          end

          context 'with an instance_group' do
            let(:path) {'/foo/jobs/dea?state=recreate'}
            let(:options) { {"job_states" => {"dea" => {"state" => "recreate"}}} }
            it_behaves_like 'recreates with configs'
          end

          context 'with an index or ID' do
            let(:path) {'/foo/jobs/dea/2?state=recreate'}
            let(:options) { {"job_states" => {"dea" => {"instance_states" => {2 => "recreate"}}}} }
            it_behaves_like 'recreates with configs'
          end
        end

          describe 'draining' do
            let(:deployment) { Models::Deployment.create(:name => 'test_deployment', :manifest => YAML.dump({'foo' => 'bar'})) }
            let(:instance) { Models::Instance.create(deployment: deployment, job: 'job_name', index: '0', uuid: '0B949287-CDED-4761-9002-FC4035E11B21', state: 'started', :variable_set => Models::VariableSet.create(deployment: deployment)) }
            before do
              Models::PersistentDisk.create(instance: instance, disk_cid: 'disk_cid')
            end

            shared_examples 'skip_drain' do
              it 'drains' do
                allow_any_instance_of(DeploymentManager).to receive(:find_by_name).and_return(deployment)
                allow_any_instance_of(DeploymentManager)
                    .to receive(:create_deployment)
                            .with(anything(), anything(), anything(), anything(), anything(), hash_excluding('skip_drain'))
                            .and_return(OpenStruct.new(:id => 1))

                put "#{path}", spec_asset('test_conf.yaml'), {'CONTENT_TYPE' => 'text/yaml'}
                expect(last_response).to be_redirect

                put '/test_deployment/jobs/job_name/0B949287-CDED-4761-9002-FC4035E11B21', spec_asset('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml' }
                expect(last_response).to be_redirect
              end

              it 'skips draining' do
                allow_any_instance_of(DeploymentManager).to receive(:find_by_name).and_return(deployment)
                allow_any_instance_of(DeploymentManager)
                    .to receive(:create_deployment)
                            .with(anything(), anything(), anything(), anything(), anything(), hash_including('skip_drain' => "#{drain_target}"))
                            .and_return(OpenStruct.new(:id => 1))

                put "#{path + drain_option}", spec_asset('test_conf.yaml'), {'CONTENT_TYPE' => 'text/yaml'}
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
            deployment = Models::Deployment.create(:name => 'foo', :manifest => YAML.dump({'foo' => 'bar'}))
            instance = Models::Instance.create(
              :deployment => deployment,
              :job => 'nats',
              :index => '0',
              :state => 'started',
              :variable_set => Models::VariableSet.create(deployment: deployment)
            )
            Models::Vm.make(agent_id: 'random-id', instance_id: instance.id, active: true)
            get '/foo/jobs/nats/0/logs', {}
            expect_redirect_to_queued_task(last_response)
          end

          it 'allows fetching logs from all instances of particular job' do
            deployment = Models::Deployment.create(:name => 'foo', :manifest => YAML.dump({'foo' => 'bar'}))
            instance = Models::Instance.create(
                :deployment => deployment,
                :job => 'nats',
                :index => '0',
                :state => 'started',
                :variable_set => Models::VariableSet.create(deployment: deployment)
            )
            Models::Vm.make(agent_id: 'random-id', instance_id: instance.id, active: true)
            get '/foo/jobs/nats/*/logs', {}
            expect_redirect_to_queued_task(last_response)
          end

          it 'allows fetching logs from all instances of particular deployment' do
            deployment = Models::Deployment.create(:name => 'foo', :manifest => YAML.dump({'foo' => 'bar'}))
            instance = Models::Instance.create(
                :deployment => deployment,
                :job => 'nats',
                :index => '0',
                :state => 'started',
                :variable_set => Models::VariableSet.create(deployment: deployment)
            )
            Models::Vm.make(agent_id: 'random-id', instance_id: instance.id, active: true)
            get '/foo/jobs/*/*/logs', {}
            expect_redirect_to_queued_task(last_response)
          end

          it '404 if no instance' do
            get '/baz/jobs/nats/0/logs', {}
            expect(last_response.status).to eq(404)
          end

          it '404 if no deployment' do
            deployment = Models::Deployment.
              create(:name => 'bar', :manifest => YAML.dump({'foo' => 'bar'}))
            get '/bar/jobs/nats/0/logs', {}
            expect(last_response.status).to eq(404)
          end
        end

        describe 'listing deployments' do
          let(:deployment) { Models::Deployment.make(name: 'b') }

          before { basic_authorize 'reader', 'reader' }

          it 'lists deployment info in deployment name order' do
            release_1 = Models::Release.create(:name => 'release-1')
            release_1_1 = Models::ReleaseVersion.create(:release => release_1, :version => 1)
            release_1_2 = Models::ReleaseVersion.create(:release => release_1, :version => 2)
            release_2 = Models::Release.create(:name => 'release-2')
            release_2_1 = Models::ReleaseVersion.create(:release => release_2, :version => 1)

            stemcell_1_1 = Models::Stemcell.create(name: 'stemcell-1', version: 1, cid: 123)
            stemcell_1_2 = Models::Stemcell.create(name: 'stemcell-1', version: 2, cid: 123)
            stemcell_2_1 = Models::Stemcell.create(name: 'stemcell-2', version: 1, cid: 124)

            old_cloud_config = Models::Config.make(:cloud, raw_manifest: {}, created_at: Time.now - 60)
            new_cloud_config = Models::Config.make(:cloud, raw_manifest: {})
            new_other_cloud_config = Models::Config.make(:cloud, name: 'other-config', raw_manifest: {})

            good_team = Models::Team.create(name: 'dabest')
            bad_team = Models::Team.create(name: 'daworst')

            deployment_3 = Models::Deployment.create(
              name: 'deployment-3',
            ).tap do |deployment|
              deployment.teams = [bad_team]
            end

            deployment_2 = Models::Deployment.create(
              name: 'deployment-2',
            ).tap do |deployment|
              deployment.add_stemcell(stemcell_1_1)
              deployment.add_stemcell(stemcell_1_2)
              deployment.add_release_version(release_1_1)
              deployment.add_release_version(release_2_1)
              deployment.teams = [good_team]
              deployment.cloud_configs = [new_other_cloud_config, new_cloud_config]
            end

            deployment_1 = Models::Deployment.create(
              name: 'deployment-1',
            ).tap do |deployment|
              deployment.add_stemcell(stemcell_1_1)
              deployment.add_stemcell(stemcell_2_1)
              deployment.add_release_version(release_1_1)
              deployment.add_release_version(release_1_2)
              deployment.teams = [good_team, bad_team]
              deployment.cloud_configs = [old_cloud_config]
            end

            get '/', {}, {}
            expect(last_response.status).to eq(200)

            body = JSON.parse(last_response.body)
            expect(body).to eq([
                  {
                    'name' => 'deployment-1',
                    'releases' => [
                      {'name' => 'release-1', 'version' => '1'},
                      {'name' => 'release-1', 'version' => '2'}
                    ],
                    'stemcells' => [
                      {'name' => 'stemcell-1', 'version' => '1'},
                      {'name' => 'stemcell-2', 'version' => '1'},
                    ],
                    'cloud_config' => 'outdated',
                    'teams' => ['dabest', 'daworst'],
                  },
                  {
                    'name' => 'deployment-2',
                    'releases' => [
                      {'name' => 'release-1', 'version' => '1'},
                      {'name' => 'release-2', 'version' => '1'}
                    ],
                    'stemcells' => [
                      {'name' => 'stemcell-1', 'version' => '1'},
                      {'name' => 'stemcell-1', 'version' => '2'},
                    ],
                    'cloud_config' => 'latest',
                    'teams' => ['dabest'],
                  },
                  {
                    'name' => 'deployment-3',
                    'releases' => [],
                    'stemcells' => [],
                    'cloud_config' => 'none',
                    'teams' => ['daworst'],
                  }
                ])
          end

          it 'orders the associations' do
            release2 = Models::Release.make(name: 'r2')
            release1 = Models::Release.make(name: 'r1')

            deployment.add_release_version(Models::ReleaseVersion.make(version: '3', release_id: release1.id))
            deployment.add_release_version(Models::ReleaseVersion.make(version: '2', release_id: release1.id))
            deployment.add_release_version(Models::ReleaseVersion.make(version: '1', release_id: release2.id))

            deployment.add_team(Models::Team.make(name: 'team2'))
            deployment.add_team(Models::Team.make(name: 'team3'))
            deployment.add_team(Models::Team.make(name: 'team1'))

            deployment.add_stemcell(Models::Stemcell.make(name: 'stemcell2', version: '4'))
            deployment.add_stemcell(Models::Stemcell.make(name: 'stemcell1', version: '1'))
            deployment.add_stemcell(Models::Stemcell.make(name: 'stemcell2', version: '3'))
            deployment.add_stemcell(Models::Stemcell.make(name: 'stemcell3', version: '2'))

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
        end

        describe 'getting deployment info' do
          before { basic_authorize 'reader', 'reader' }

          it 'returns manifest' do
            deployment = Models::Deployment.
                create(:name => 'test_deployment',
                       :manifest_text => YAML.dump({'foo' => 'bar'}))
            get '/test_deployment'

            expect(last_response.status).to eq(200)
            body = JSON.parse(last_response.body)
            expect(YAML.load(body['manifest'])).to eq('foo' => 'bar')
          end
        end

        describe 'getting deployment vms info' do
          before { basic_authorize 'reader', 'reader' }

          let(:deployment) { Models::Deployment.create(:name => 'test_deployment', :manifest => YAML.dump({'foo' => 'bar'})) }

          it 'returns a list of instances with vms (vm_cid != nil)' do
            8.times do |i|
              instance_params = {
                'deployment_id' => deployment.id,
                'job' => "job-#{i}",
                'index' => i,
                'state' => 'started',
                'uuid' => "instance-#{i}",
                'variable_set_id' => (Models::VariableSet.create(deployment: deployment).id)
              }

              instance_params['availability_zone'] = "az0" if i == 0
              instance_params['availability_zone'] = "az1" if i == 1
              instance = Models::Instance.create(instance_params)
              2.times do |j|
                vm_params = {
                  'agent_id' => "agent-#{i}-#{j}",
                  'cid' => "cid-#{i}-#{j}",
                  'instance_id' => instance.id,
                  'created_at' => time
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
              expect(instance_with_vm).to eq(
                'agent_id' => "agent-#{instance_idx}-#{vm_by_instance}",
                'job' => "job-#{instance_idx}",
                'index' => instance_idx,
                'cid' => "cid-#{instance_idx}-#{vm_by_instance}",
                'id' => "instance-#{instance_idx}",
                'az' => {0 => "az0", 1 => "az1", nil => nil}[instance_idx],
                'ips' => [],
                'vm_created_at' => time.utc.iso8601
              )
            end
          end

          context 'with full format requested' do
            before do
              deployment
            end

            it 'redirects to a delayed job' do
              allow_any_instance_of(Api::InstanceManager).to receive(:fetch_instances_with_vm) do
                Bosh::Director::Models::Task.make(id: 10002)
              end

              get '/test_deployment/vms?format=full'

              task = expect_redirect_to_queued_task(last_response)
              expect(task.id).to eq 10002
            end
          end

          context 'ips' do
            it 'returns instance ip addresses' do
              15.times do |i|
                instance_params = {
                  'deployment_id' => deployment.id,
                  'job' => "job-#{i}",
                  'index' => i,
                  'state' => 'started',
                  'uuid' => "instance-#{i}",
                  'variable_set_id' => (Models::VariableSet.create(deployment: deployment).id)
                }

                instance_params['availability_zone'] = "az0" if i == 0
                instance_params['availability_zone'] = "az1" if i == 1
                instance = Models::Instance.create(instance_params)
                vm_params = {
                  'agent_id' => "agent-#{i}",
                  'cid' => "cid-#{i}",
                  'instance_id' => instance.id,
                  'created_at' => time
                }

                vm = Models::Vm.create(vm_params)
                if i < 8
                  instance.active_vm = vm
                end

                ip_addresses_params  = {
                  'instance_id' => instance.id,
                  'task_id' => "#{i}",
                  'address_str' => ip_to_i("1.2.3.#{i}").to_s,
                }
                Models::IpAddress.create(ip_addresses_params)
              end

              get '/test_deployment/vms'

              expect(last_response.status).to eq(200)
              body = JSON.parse(last_response.body)
              expect(body.size).to eq(15)

              body.sort_by{|instance| instance['index']}.each_with_index do |instance_with_vm, i|
                expect(instance_with_vm).to eq(
                  'agent_id' => "agent-#{i}",
                  'job' => "job-#{i}",
                  'index' => i,
                  'cid' => "cid-#{i}",
                  'id' => "instance-#{i}",
                  'az' => {0 => "az0", 1 => "az1", nil => nil}[i],
                  'ips' => ["1.2.3.#{i}"],
                  'vm_created_at' => time.utc.iso8601
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
                  'spec_json' => "{ \"networks\": [ [ \"a\", { \"ip\": \"1.2.3.#{i}\" } ] ] }",
                }

                instance_params['availability_zone'] = "az0" if i == 0
                instance_params['availability_zone'] = "az1" if i == 1
                instance = Models::Instance.create(instance_params)
                vm_params = {
                  'agent_id' => "agent-#{i}",
                  'cid' => "cid-#{i}",
                  'instance_id' => instance.id,
                  'created_at' => time
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
                expect(instance_with_vm).to eq(
                  'agent_id' => "agent-#{i}",
                  'job' => "job-#{i}",
                  'index' => i,
                  'cid' => "cid-#{i}",
                  'id' => "instance-#{i}",
                  'az' => {0 => "az0", 1 => "az1", nil => nil}[i],
                  'ips' => ["1.2.3.#{i}"],
                  'vm_created_at' => time.utc.iso8601
                )
              end
            end
          end
        end

        describe 'getting deployment instances' do
          before do
            basic_authorize 'reader', 'reader'
            release = Models::Release.create(:name => 'test_release')
            version = Models::ReleaseVersion.create(:release => release, :version => 1)
            version.add_template(Models::Template.make(name: 'job_using_pkg_1', release: release))
          end
          let(:deployment) { Models::Deployment.create(:name => 'test_deployment', :manifest => manifest) }
          let(:default_manifest) { Bosh::Spec::Deployments.remote_stemcell_manifest('stemcell_url', 'stemcell_sha1') }

          context 'multiple instances' do
            let(:manifest) {
              jobs = []
              15.times do |i|
                jobs << {
                    'name' => "job-#{i}",
                    'spec' => {'templates' => [{'name' => 'job_using_pkg_1'}]},
                    'instances' => 1,
                    'resource_pool' => 'a',
                    'networks' => [{ 'name' => 'a' }]
                }
              end
              YAML.dump(default_manifest.merge({'jobs' => jobs}))
            }

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

                instance_params['availability_zone'] = "az0" if i == 0
                instance_params['availability_zone'] = "az1" if i == 1
                instance = Models::Instance.create(instance_params)
                if i < 6
                  vm_params = {
                    'agent_id' => "agent-#{i}",
                    'cid' => "cid-#{i}",
                    'instance_id' => instance.id,
                    'created_at' => time
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
                    'az' => {0 => "az0", 1 => "az1", nil => nil}[i],
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
                    'az' => {0 => "az0", 1 => "az1", nil => nil}[i],
                    'ips' => [],
                    'vm_created_at' => nil,
                    'expects_vm' => true
                  )
                end
              end
            end

            context 'ips' do
              it 'returns instance ip addresses' do
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

                  instance_params['availability_zone'] = "az0" if i == 0
                  instance_params['availability_zone'] = "az1" if i == 1
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
                                          'az' => {0 => "az0", 1 => "az1", nil => nil}[i],
                                          'ips' => ["1.2.3.#{i}"],
                                          'vm_created_at' => nil,
                                          'expects_vm' => true
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
                      'spec_json' => "{ \"lifecycle\": \"service\", \"networks\": [ [ \"a\", { \"ip\": \"1.2.3.#{i}\" } ] ] }",
                  }

                  instance_params['availability_zone'] = "az0" if i == 0
                  instance_params['availability_zone'] = "az1" if i == 1
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
                                          'az' => {0 => "az0", 1 => "az1", nil => nil}[i],
                                          'ips' => ["1.2.3.#{i}"],
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
              let(:manifest) { YAML.dump(default_manifest.merge(Bosh::Spec::Deployments.test_release_job)) }
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
              let(:manifest) { YAML.dump(default_manifest.merge(Bosh::Spec::Deployments.test_release_job)) }
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

        describe 'property management' do

          it 'REST API for creating, updating, getting and deleting ' +
                 'deployment properties' do

            deployment = Models::Deployment.make(:name => 'mycloud')

            get '/mycloud/properties/foo'
            expect(last_response.status).to eq(404)

            get '/othercloud/properties/foo'
            expect(last_response.status).to eq(404)

            post '/mycloud/properties', JSON.generate('name' => 'foo', 'value' => 'bar'), { 'CONTENT_TYPE' => 'application/json' }
            expect(last_response.status).to eq(204)

            get '/mycloud/properties/foo'
            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body)['value']).to eq('bar')

            get '/othercloud/properties/foo'
            expect(last_response.status).to eq(404)

            put '/mycloud/properties/foo', JSON.generate('value' => 'baz'), { 'CONTENT_TYPE' => 'application/json' }
            expect(last_response.status).to eq(204)

            get '/mycloud/properties/foo'
            expect(JSON.parse(last_response.body)['value']).to eq('baz')

            delete '/mycloud/properties/foo'
            expect(last_response.status).to eq(204)

            get '/mycloud/properties/foo'
            expect(last_response.status).to eq(404)
          end
        end

        describe 'problem management' do
          let!(:deployment) { Models::Deployment.make(:name => 'mycloud') }
          let(:job_class) do
            Class.new(Jobs::CloudCheck::ScanAndFix) do
              define_method :perform do
                'foo'
              end
              @queue = :normal
            end
          end
          let (:db_job) { Jobs::DBJob.new(job_class, task.id, args)}

          it 'exposes problem managent REST API' do
            get '/mycloud/problems'
            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body)).to eq([])

            post '/mycloud/scans'
            expect_redirect_to_queued_task(last_response)

            put '/mycloud/problems', JSON.generate('solutions' => { 42 => 'do_this', 43 => 'do_that', 44 => nil }), { 'CONTENT_TYPE' => 'application/json' }
            expect_redirect_to_queued_task(last_response)

            problem = Models::DeploymentProblem.
                create(:deployment_id => deployment.id, :resource_id => 2,
                       :type => 'test', :state => 'open', :data => {})

            put '/mycloud/problems', JSON.generate('solution' => 'default'), { 'CONTENT_TYPE' => 'application/json' }
            expect_redirect_to_queued_task(last_response)
          end
        end

        describe 'resurrection' do
          let!(:deployment) { Models::Deployment.make(:name => 'mycloud') }

          def should_not_enqueue_scan_and_fix
            expect(Bosh::Director::Jobs::DBJob).not_to receive(:new).with(
              Jobs::CloudCheck::ScanAndFix,
              kind_of(Numeric),
              ['mycloud',
              [['job', 0]], false])
            expect(Delayed::Job).not_to receive(:enqueue)
            put '/mycloud/scan_and_fix', JSON.dump('jobs' => {'job' => [0]}), {'CONTENT_TYPE' => 'application/json'}
            expect(last_response).not_to be_redirect
          end

          def should_enqueue_scan_and_fix
            expect(Bosh::Director::Jobs::DBJob).to receive(:new).with(
              Jobs::CloudCheck::ScanAndFix,
              kind_of(Numeric),
              ['mycloud',
              [['job', 0]], false])
            expect(Delayed::Job).to receive(:enqueue)
            put '/mycloud/scan_and_fix',  JSON.generate('jobs' => {'job' => [0]}), {'CONTENT_TYPE' => 'application/json'}
            expect_redirect_to_queued_task(last_response)
          end

          context 'when global resurrection is not set' do
            it 'scans and fixes problems' do
              Models::Instance.make(deployment: deployment, job: 'job', index: 0)
              should_enqueue_scan_and_fix
            end
          end

          context 'when global resurrection is set' do
            before { Models::DirectorAttribute.make(name: 'resurrection_paused', value: resurrection_paused) }

            context 'when global resurrection is on' do
              let (:resurrection_paused) {'false'}

              it 'does not run scan_and_fix task if instances resurrection is off' do
                Models::Instance.make(deployment: deployment, job: 'job', index: 0, resurrection_paused: true)
                should_not_enqueue_scan_and_fix
              end

              it 'runs scan_and_fix task if instances resurrection is on' do
                Models::Instance.make(deployment: deployment, job: 'job', index: 0)
                should_enqueue_scan_and_fix
              end
            end

            context 'when global resurrection is off' do
              let (:resurrection_paused) {'true'}

              it 'does not run scan_and_fix task if instances resurrection is off' do
                Models::Instance.make(deployment: deployment, job: 'job', index: 0, resurrection_paused: true)
                should_not_enqueue_scan_and_fix
              end
            end
          end

          context 'when there are only ignored vms' do
            it 'does not call the resurrector' do
              Models::Instance.make(deployment: deployment, job: 'job', index: 0, resurrection_paused: false, ignore: true)

              put '/mycloud/scan_and_fix', JSON.generate('jobs' => {'job' => [0]}), {'CONTENT_TYPE' => 'application/json'}
              expect(last_response).not_to be_redirect
            end
          end
        end

        describe 'snapshots' do
          before do
            deployment = Models::Deployment.make(name: 'mycloud')

            instance = Models::Instance.make(deployment: deployment, job: 'job', index: 0, uuid: 'abc123')
            disk = Models::PersistentDisk.make(disk_cid: 'disk0', instance: instance, active: true)
            Models::Snapshot.make(persistent_disk: disk, snapshot_cid: 'snap0a')

            instance = Models::Instance.make(deployment: deployment, job: 'job', index: 1)
            disk = Models::PersistentDisk.make(disk_cid: 'disk1', instance: instance, active: true)
            Models::Snapshot.make(persistent_disk: disk, snapshot_cid: 'snap1a')
            Models::Snapshot.make(persistent_disk: disk, snapshot_cid: 'snap1b')
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
              snap = Models::Snapshot.make(snapshot_cid: 'snap2b')
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

            let(:cloud_config) { Models::Config.make(:cloud, content: YAML.dump(Bosh::Spec::NewDeployments.simple_cloud_config)) }

            let(:service_errand) do
              {
                'name' => 'service_errand_job',
                'jobs' => [{'name' => 'job_with_bin_run'}],
                'lifecycle' => 'service',
                'vm_type' => 'a',
                'stemcell' => 'default',
                'instances' => 1,
                'networks' => [{'name' => 'a'}]
              }
            end

            let!(:deployment_model) do
              manifest_hash = manifest_with_errand_hash
              manifest_hash['instance_groups'] << service_errand
              model = Models::Deployment.make(
                name: 'fake-dep-name',
                manifest: YAML.dump(manifest_hash)
              )
              model.cloud_configs = [cloud_config]
              model
            end

            context 'authenticated access' do
              before do
                authorize 'admin', 'admin'
                deployment = Models::Deployment.make(name: 'errand')
                Models::VariableSet.make(deployment_id: deployment.id)
                release = Models::Release.make(name: 'bosh-release')
                template1 = Models::Template.make(name: 'foobar', release: release)
                template2 = Models::Template.make(name: 'errand1', release: release)
                template3 = Models::Template.make(name: 'job_with_bin_run', release: release, spec: {templates: {'foo' => 'bin/run'}})
                release_version = Models::ReleaseVersion.make(version: '0.1-dev', release: release)
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

            let!(:deployment) { Models::Deployment.make(name: 'fake-dep-name')}

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
                    ""
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
                    ""
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
                    ""
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
                    ""
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
          let(:runtime_config_1) { Models::Config.make(type: 'runtime', raw_manifest: {'addons' => []}) }
          let(:runtime_config_2) { Models::Config.make(type: 'runtime', raw_manifest: {'addons' => []}) }
          let(:runtime_config_3) { Models::Config.make(type: 'runtime', raw_manifest: {'addons' => []}, name: 'smurf') }
          let(:cloud_config) { Models::Config.make(:cloud, raw_manifest: {'azs' => []}) }

          before do
            deployment = Models::Deployment.create(
              :name => 'fake-dep-name',
              :manifest => YAML.dump({'instance_groups' => [], 'releases' => [{'name' => 'simple', 'version' => 5}]})
            )
            deployment.cloud_configs = [cloud_config]
            deployment.runtime_configs = [runtime_config_1, runtime_config_2, runtime_config_3]
          end

          context 'authenticated access' do
            before { authorize 'admin', 'admin' }

            it 'returns diff with resolved aliases' do
              perform
              expect(last_response.body).to eq("{\"context\":{\"cloud_config_ids\":[#{cloud_config.id}],\"runtime_config_ids\":[#{runtime_config_2.id},#{runtime_config_3.id}]},\"diff\":[[\"instance_groups: []\",\"removed\"],[\"\",null],[\"name: fake-dep-name\",\"added\"]]}")
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

            context 'when cloud config exists' do
              let(:manifest_hash) { {'instance_groups' => [], 'releases' => [{'name' => 'simple', 'version' => 5}], 'networks' => [{'name'=> 'non-cloudy-network'}]}}

              it 'ignores cloud config if network section exists' do
                Models::Deployment.create(
                  :name => 'fake-dep-name-no-cloud-conf',
                  :manifest => YAML.dump(manifest_hash)
                )

                Models::Config.make(:cloud, raw_manifest: {'networks'=>[{'name'=>'very-cloudy-network'}]})

                manifest_hash['networks'] = [{'name'=> 'network2'}]
                diff = post '/fake-dep-name-no-cloud-conf/diff', YAML.dump(manifest_hash), {'CONTENT_TYPE' => 'text/yaml'}

                expect(diff).not_to match /very-cloudy-network/
                expect(diff).to match /non-cloudy-network/
                expect(diff).to match /network2/
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
          let(:deployment_1) { Models::Deployment.make(name: 'test_deployment_1', manifest: '') }
          let(:deployment_2) { Models::Deployment.make(name: 'test_deployment_2', manifest: '') }

          let(:variable_set_1) { Models::VariableSet.make(id: 1, deployment: deployment_1) }
          let(:variable_set_2) { Models::VariableSet.make(id: 2, deployment: deployment_1) }
          let(:variable_set_3) { Models::VariableSet.make(id: 12, deployment: deployment_2) }
          let(:variable_set_4) { Models::VariableSet.make(id: 13, deployment: deployment_2) }

          before do
            basic_authorize 'admin', 'admin'

            Models::Variable.make(id: 1, variable_id: 'var_id_1', variable_name: 'var_name_1', variable_set_id: variable_set_1.id)
            Models::Variable.make(id: 2, variable_id: 'var_id_2', variable_name: 'var_name_2', variable_set_id: variable_set_1.id)
            Models::Variable.make(id: 3, variable_id: 'var_id_1', variable_name: 'var_name_1', variable_set_id: variable_set_2.id)
            Models::Variable.make(id: 4, variable_id: 'var_id_3', variable_name: 'var_name_3', variable_set_id: variable_set_2.id)

            Models::Variable.make(id: 5, variable_id: 'var_id_1', variable_name: 'var_name_1', variable_set_id: variable_set_3.id)
            Models::Variable.make(id: 6, variable_id: 'var_id_2', variable_name: 'var_name_2', variable_set_id: variable_set_3.id)
            Models::Variable.make(id: 7, variable_id: 'var_id_3', variable_name: 'var_name_3', variable_set_id: variable_set_4.id)
            Models::Variable.make(id: 8, variable_id: 'var_id_4', variable_name: 'var_name_4', variable_set_id: variable_set_4.id)
          end

          it 'returns a unique list of variable ids and names' do
            get '/test_deployment_1/variables'
            expect(last_response.status).to eq(200)
            vars_1 = JSON.parse(last_response.body)
            expect(vars_1).to match_array([
              {'id' => 'var_id_1', 'name' => 'var_name_1'},
              {'id' => 'var_id_2', 'name' => 'var_name_2'},
              {'id' => 'var_id_3', 'name' => 'var_name_3'}
            ])

            get '/test_deployment_2/variables'
            expect(last_response.status).to eq(200)
            vars_2 = JSON.parse(last_response.body)
            expect(vars_2).to match_array([
              {'id' => 'var_id_1', 'name' => 'var_name_1'},
              {'id' => 'var_id_2', 'name' => 'var_name_2'},
              {'id' => 'var_id_3', 'name' => 'var_name_3'},
              {'id' => 'var_id_4', 'name' => 'var_name_4'}
            ])
          end

          context 'when deployment does not have variables' do
            before { Models::Deployment.make(name: 'test_deployment_3', manifest: '') }

            it 'returns an empty array' do
              get '/test_deployment_3/variables'
              expect(last_response.status).to eq(200)
              vars_3 = JSON.parse(last_response.body)
              expect(vars_3).to be_empty
            end
          end
        end
      end

      describe 'authorization' do
        before do
          release = Models::Release.make(name: 'bosh-release')
          template1 = Models::Template.make(name: 'foobar', release: release)
          template2 = Models::Template.make(name: 'errand1', release: release)
          release_version = Models::ReleaseVersion.make(version: '0.1-dev', release: release)
          release_version.add_template(template1)
          release_version.add_template(template2)
        end

        let(:dev_team) { Models::Team.create(:name => 'dev') }
        let(:other_team) { Models::Team.create(:name => 'other') }
        let!(:owned_deployment) { Models::Deployment.create_with_teams(:name => 'owned_deployment', teams: [dev_team], manifest: manifest_with_errand('owned_deployment'), cloud_configs: [cloud_config]) }
        let!(:other_deployment) { Models::Deployment.create_with_teams(:name => 'other_deployment', teams: [other_team], manifest: manifest_with_errand('other_deployment'), cloud_configs: [cloud_config]) }
        describe 'when a user has dev team admin membership' do

          before {
            instance = Models::Instance.create(:deployment => owned_deployment, :job => 'dea', :index => 0, :state => :started, :uuid => 'F0753566-CA8E-4B28-AD63-7DB3903CD98C', :variable_set => Models::VariableSet.create(deployment: owned_deployment))
            Models::Instance.create(:deployment => other_deployment, :job => 'dea', :index => 0, :state => :started, :uuid => '72652FAA-1A9C-4803-8423-BBC3630E49C6', :variable_set => Models::VariableSet.create(deployment: other_deployment))
            Models::Vm.make(agent_id: 'random-id', instance_id: instance.id, active: true)
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
              expect(put('/owned_deployment/jobs/dea/0/resurrection', '{}', { 'CONTENT_TYPE' => 'application/json' }).status).to eq(200)
            end
            it 'denies access to other deployment' do
              expect(put('/other_deployment/jobs/dea/0/resurrection', '{}', { 'CONTENT_TYPE' => 'application/json' }).status).to eq(401)
            end
          end

          context 'PUT /:deployment/instance_groups/:instancegroup/:id/ignore' do
            it 'allows access to owned deployment' do
              expect(put('/owned_deployment/instance_groups/dea/F0753566-CA8E-4B28-AD63-7DB3903CD98C/ignore', '{}', { 'CONTENT_TYPE' => 'application/json' }).status).to eq(200)
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
              instance = Models::Instance.make(deployment: owned_deployment)
              persistent_disk = Models::PersistentDisk.make(instance: instance)
              Models::Snapshot.make(persistent_disk: persistent_disk, snapshot_cid: 'cid-1')
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

          context 'GET /:deployment/properties' do
            it 'allows access to owned deployment' do
              expect(get('/owned_deployment/properties').status).to eq(200)
            end

            it 'denies access to other deployment' do
              expect(get('/other_deployment/properties').status).to eq(401)
            end
          end

          context 'GET /:deployment/properties/:property' do
            before { Models::DeploymentProperty.make(deployment: owned_deployment, name: 'prop', value: 'value') }
            it 'allows access to owned deployment' do
              expect(get('/owned_deployment/properties/prop').status).to eq(200)
            end

            it 'denies access to other deployment' do
              expect(get('/other_deployment/properties/prop').status).to eq(401)
            end
          end

          context 'POST /:deployment/properties' do
            it 'allows access to owned deployment' do
              expect(post('/owned_deployment/properties', '{"name": "prop", "value": "bingo"}', { 'CONTENT_TYPE' => 'application/json' }).status).to eq(204)
            end

            it 'denies access to other deployment' do
              expect(post('/other_deployment/properties', '{"name": "prop", "value": "bingo"}', { 'CONTENT_TYPE' => 'application/json' }).status).to eq(401)
            end
          end

          context 'PUT /:deployment/properties/:property' do
            before { Models::DeploymentProperty.make(deployment: owned_deployment, name: 'prop', value: 'value') }
            it 'allows access to owned deployment' do
              expect(put('/owned_deployment/properties/prop', '{"value": "bingo"}', { 'CONTENT_TYPE' => 'application/json' }).status).to eq(204)
            end

            it 'denies access to other deployment' do
              expect(put('/other_deployment/properties/prop', '{"value": "bingo"}', { 'CONTENT_TYPE' => 'application/json' }).status).to eq(401)
            end
          end

          context 'DELETE /:deployment/properties/:property' do
            before { Models::DeploymentProperty.make(deployment: owned_deployment, name: 'prop', value: 'value') }
            it 'allows access to owned deployment' do
              expect(delete('/owned_deployment/properties/prop').status).to eq(204)
            end

            it 'denies access to other deployment' do
              expect(delete('/other_deployment/properties/prop').status).to eq(401)
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

            let(:cloud_config) { Models::Config.make(:cloud, content: YAML.dump(Bosh::Spec::NewDeployments.simple_cloud_config)) }

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
