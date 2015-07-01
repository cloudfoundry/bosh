require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::DeploymentsController do
      include Rack::Test::Methods

      subject(:app) { described_class.new(config) }
      let(:config) { Config.load_hash(test_config) }

      let(:temp_dir) { Dir.mktmpdir}
      let(:test_config) do
        blobstore_dir = File.join(temp_dir, 'blobstore')
        FileUtils.mkdir_p(blobstore_dir)

        config = Psych.load(spec_asset('test-director-config.yml'))
        config['dir'] = temp_dir
        config['blobstore'] = {
          'provider' => 'local',
          'options' => {'blobstore_path' => blobstore_dir}
        }
        config['snapshots']['enabled'] = true
        config
      end

      before do
        App.new(config)
        basic_authorize 'admin', 'admin'
      end

      after { FileUtils.rm_rf(temp_dir) }

      it 'sets the date header' do
        get '/'
        expect(last_response.headers['Date']).to be
      end

      describe 'API calls' do
        describe 'creating a deployment' do
          it 'expects compressed deployment file' do
            post '/', spec_asset('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml' }
            expect_redirect_to_queued_task(last_response)
          end

          it 'only consumes text/yaml' do
            post '/', spec_asset('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/plain' }
            expect(last_response.status).to eq(404)
          end
        end

        describe 'job management' do
          it 'allows putting jobs into different states' do
            Models::Deployment.
                create(:name => 'foo', :manifest => Psych.dump({'foo' => 'bar'}))
            put '/foo/jobs/nats?state=stopped', spec_asset('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml' }
            expect_redirect_to_queued_task(last_response)
          end

          it 'allows putting job instances into different states' do
            Models::Deployment.
                create(:name => 'foo', :manifest => Psych.dump({'foo' => 'bar'}))
            put '/foo/jobs/dea/2?state=stopped', spec_asset('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml' }
            expect_redirect_to_queued_task(last_response)
          end

          it 'allows putting job instances into different states with content_length of 0' do
            RSpec::Matchers.define :not_to_have_body do |unexpected|
              match { |actual| actual.read != unexpected.read }
            end

            manifest = spec_asset('test_conf.yaml')
            allow_any_instance_of(DeploymentManager).to receive(:create_deployment).
                with(anything(), not_to_have_body(StringIO.new(manifest)), anything(), anything()).
                and_return(OpenStruct.new(:id => 'no_content_length'))
            Models::Deployment.
              create(:name => 'foo', :manifest => Psych.dump({'foo' => 'bar'}))
            put '/foo/jobs/dea/2?state=stopped', manifest, {'CONTENT_TYPE' => 'text/yaml', 'CONTENT_LENGTH' => 0}

            match = last_response.location.match(%r{/tasks/no_content_length})
            expect(match).to_not be_nil
          end

          it 'allows putting the job instance into different resurrection_paused values' do
            deployment = Models::Deployment.
                create(:name => 'foo', :manifest => Psych.dump({'foo' => 'bar'}))
            instance = Models::Instance.
                create(:deployment => deployment, :job => 'dea',
                       :index => '0', :state => 'started')
            put '/foo/jobs/dea/0/resurrection', Yajl::Encoder.encode('resurrection_paused' => true), { 'CONTENT_TYPE' => 'application/json' }
            expect(last_response.status).to eq(200)
            expect(instance.reload.resurrection_paused).to be(true)
          end

          it "doesn't like invalid indices" do
            put '/foo/jobs/dea/zb?state=stopped', spec_asset('test_conf.yaml'), { 'CONTENT_TYPE' => 'text/yaml' }
           expect(last_response.status).to eq(400)
          end

          it 'can get job information' do
            deployment = Models::Deployment.create(name: 'foo', manifest: Psych.dump({'foo' => 'bar'}))
            instance = Models::Instance.create(deployment: deployment, job: 'nats', index: '0', state: 'started')
            Models::PersistentDisk.create(instance: instance, disk_cid: 'disk_cid')

            get '/foo/jobs/nats/0', {}

            expect(last_response.status).to eq(200)
            expected = {
                'deployment' => 'foo',
                'job' => 'nats',
                'index' => 0,
                'state' => 'started',
                'disks' => %w[disk_cid]
            }

            expect(Yajl::Parser.parse(last_response.body)).to eq(expected)
          end

          it 'should return 404 if the instance cannot be found' do
            get '/foo/jobs/nats/0', {}
            expect(last_response.status).to eq(404)
          end
        end

        describe 'log management' do
          it 'allows fetching logs from a particular instance' do
            deployment = Models::Deployment.create(:name => 'foo', :manifest => Psych.dump({'foo' => 'bar'}))
            Models::Instance.create(
              :deployment => deployment,
              :job => 'nats',
              :index => '0',
              :state => 'started',
            )
            get '/foo/jobs/nats/0/logs', {}
            expect_redirect_to_queued_task(last_response)
          end

          it '404 if no instance' do
            get '/baz/jobs/nats/0/logs', {}
            expect(last_response.status).to eq(404)
          end

          it '404 if no deployment' do
            deployment = Models::Deployment.
                create(:name => 'bar', :manifest => Psych.dump({'foo' => 'bar'}))
            get '/bar/jobs/nats/0/logs', {}
            expect(last_response.status).to eq(404)
          end
        end

        describe 'listing deployments' do
          it 'lists deployment info in deployment name order' do

            release_1 = Models::Release.create(:name => "release-1")
            release_1_1 = Models::ReleaseVersion.create(:release => release_1, :version => 1)
            release_1_2 = Models::ReleaseVersion.create(:release => release_1, :version => 2)
            release_2 = Models::Release.create(:name => "release-2")
            release_2_1 = Models::ReleaseVersion.create(:release => release_2, :version => 1)

            stemcell_1_1 = Models::Stemcell.create(name: "stemcell-1", version: 1, cid: 123)
            stemcell_1_2 = Models::Stemcell.create(name: "stemcell-1", version: 2, cid: 123)
            stemcell_2_1 = Models::Stemcell.create(name: "stemcell-2", version: 1, cid: 124)

            old_cloud_config = Models::CloudConfig.make(manifest: {}, created_at: Time.now - 60)
            new_cloud_config = Models::CloudConfig.make(manifest: {})

            deployment_3 = Models::Deployment.create(
              name: "deployment-3",
            )

            deployment_2 = Models::Deployment.create(
              name: "deployment-2",
              cloud_config: new_cloud_config,
            ).tap do |deployment|
              deployment.add_stemcell(stemcell_1_1)
              deployment.add_stemcell(stemcell_1_2)
              deployment.add_release_version(release_1_1)
              deployment.add_release_version(release_2_1)
            end

            deployment_1 = Models::Deployment.create(
              name: "deployment-1",
              cloud_config: old_cloud_config,
            ).tap do |deployment|
              deployment.add_stemcell(stemcell_1_1)
              deployment.add_stemcell(stemcell_2_1)
              deployment.add_release_version(release_1_1)
              deployment.add_release_version(release_1_2)
            end

            get '/', {}, {}
            expect(last_response.status).to eq(200)

            body = Yajl::Parser.parse(last_response.body)
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
                  },
                  {
                    'name' => 'deployment-3',
                    'releases' => [],
                    'stemcells' => [],
                    'cloud_config' => 'none',
                  }
                ])
          end
        end

        describe 'getting deployment info' do
          it 'returns manifest' do
            deployment = Models::Deployment.
                create(:name => 'test_deployment',
                       :manifest => Psych.dump({'foo' => 'bar'}))
            get '/test_deployment'

            expect(last_response.status).to eq(200)
            body = Yajl::Parser.parse(last_response.body)
            expect(Psych.load(body['manifest'])).to eq('foo' => 'bar')
          end
        end

        describe 'getting deployment vms info' do
          it 'returns a list of agent_ids, jobs and indices' do
            deployment = Models::Deployment.
                create(:name => 'test_deployment',
                       :manifest => Psych.dump({'foo' => 'bar'}))

            15.times do |i|
              vm_params = {
                  'agent_id' => "agent-#{i}",
                  'cid' => "cid-#{i}",
                  'deployment_id' => deployment.id
              }
              vm = Models::Vm.create(vm_params)

              instance_params = {
                  'deployment_id' => deployment.id,
                  'vm_id' => vm.id,
                  'job' => "job-#{i}",
                  'index' => i,
                  'state' => 'started'
              }
              Models::Instance.create(instance_params)
            end

            get '/test_deployment/vms'

            expect(last_response.status).to eq(200)
            body = Yajl::Parser.parse(last_response.body)
            expect(body.size).to eq(15)

            15.times do |i|
              expect(body[i]).to eq(
                  'agent_id' => "agent-#{i}",
                  'job' => "job-#{i}",
                  'index' => i,
                  'cid' => "cid-#{i}",
              )
            end
          end
        end

        describe 'deleting deployment' do
          it 'deletes the deployment' do
            deployment = Models::Deployment.create(:name => 'test_deployment', :manifest => Psych.dump({'foo' => 'bar'}))

            delete '/test_deployment'
            expect_redirect_to_queued_task(last_response)
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

            post '/mycloud/properties', Yajl::Encoder.encode('name' => 'foo', 'value' => 'bar'), { 'CONTENT_TYPE' => 'application/json' }
            expect(last_response.status).to eq(204)

            get '/mycloud/properties/foo'
            expect(last_response.status).to eq(200)
            expect(Yajl::Parser.parse(last_response.body)['value']).to eq('bar')

            get '/othercloud/properties/foo'
            expect(last_response.status).to eq(404)

            put '/mycloud/properties/foo', Yajl::Encoder.encode('value' => 'baz'), { 'CONTENT_TYPE' => 'application/json' }
            expect(last_response.status).to eq(204)

            get '/mycloud/properties/foo'
            expect(Yajl::Parser.parse(last_response.body)['value']).to eq('baz')

            delete '/mycloud/properties/foo'
            expect(last_response.status).to eq(204)

            get '/mycloud/properties/foo'
            expect(last_response.status).to eq(404)
          end
        end

        describe 'problem management' do
          let!(:deployment) { Models::Deployment.make(:name => 'mycloud') }

          it 'exposes problem managent REST API' do
            get '/mycloud/problems'
            expect(last_response.status).to eq(200)
            expect(Yajl::Parser.parse(last_response.body)).to eq([])

            post '/mycloud/scans'
            expect_redirect_to_queued_task(last_response)

            put '/mycloud/problems', Yajl::Encoder.encode('solutions' => { 42 => 'do_this', 43 => 'do_that', 44 => nil }), { 'CONTENT_TYPE' => 'application/json' }
            expect_redirect_to_queued_task(last_response)

            problem = Models::DeploymentProblem.
                create(:deployment_id => deployment.id, :resource_id => 2,
                       :type => 'test', :state => 'open', :data => {})

            put '/mycloud/problems', Yajl::Encoder.encode('solution' => 'default'), { 'CONTENT_TYPE' => 'application/json' }
            expect_redirect_to_queued_task(last_response)
          end

          it 'scans and fixes problems' do
            expect(Resque).to receive(:enqueue).with(
                Jobs::CloudCheck::ScanAndFix,
                kind_of(Numeric),
                'mycloud',
                [['job', 0], ['job', 1], ['job', 6]],
                false
              )
            put '/mycloud/scan_and_fix', Yajl::Encoder.encode('jobs' => {'job' => [0, 1, 6]}), {'CONTENT_TYPE' => 'application/json'}
            expect_redirect_to_queued_task(last_response)
          end
        end

        describe 'snapshots' do
          before do
            deployment = Models::Deployment.make(name: 'mycloud')

            instance = Models::Instance.make(deployment: deployment, job: 'job', index: 0)
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

            let!(:deployment_model) do

              manifest_hash = Bosh::Spec::Deployments.manifest_with_errand
              manifest_hash['jobs'] << {
                'name' => 'another-errand',
                'template' => 'errand1',
                'lifecycle' => 'errand',
                'resource_pool' => 'a',
                'instances' => 1,
                'networks' => [{'name' => 'a'}]
              }
              Models::Deployment.make(
                name: 'fake-dep-name',
                manifest: Psych.dump(manifest_hash),
                cloud_config: cloud_config
              )
            end
            let(:cloud_config) { Models::CloudConfig.make }

            before { allow(Config).to receive(:event_log).with(no_args).and_return(event_log) }
            let(:event_log) { instance_double('Bosh::Director::EventLog::Log', track: nil) }

            before { allow(Config).to receive(:logger).with(no_args).and_return(logger) }

            context 'authenticated access' do
              before { authorize 'admin', 'admin' }

              it 'returns errands in deployment' do
                response = perform
                expect(response.body).to eq('[{"name":"fake-errand-name"},{"name":"another-errand"}]')
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
                    ['fake-dep-name', 'fake-errand-name', false],
                  ).and_return(task)

                  perform({})
                end

                it 'enqueues a keep-alive task' do
                  expect(job_queue).to receive(:enqueue).with(
                    'admin',
                    Jobs::RunErrand,
                    'run errand fake-errand-name from deployment fake-dep-name',
                    ['fake-dep-name', 'fake-errand-name', true],
                  ).and_return(task)

                  perform({'keep-alive' => true})
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
      end

      describe 'scope' do
        let(:identity_provider) { Support::TestIdentityProvider.new }
        let(:config) do
          config = Config.load_hash(test_config)
          allow(config).to receive(:identity_provider).and_return(identity_provider)
          config
        end

        it 'accepts read scope for routes allowing read access' do
          read_routes = [
            '/',
            '/deployment-name',
            '/deployment-name/errands',
            '/deployment-name/vms'
          ]

          read_routes.each do |route|
            get route
            expect(identity_provider.scope).to eq(:read)
          end

          non_read_routes = [
            [:get, '/deployment-name/jobs/fake-job/0'],
            [:put, '/deployment-name/jobs/0'],
            [:post, '/deployment-name/ssh'],
            [:post, '/deployment-name/scans'],
          ]

          non_read_routes.each do |method, route|
            method(method).call(route)
            expect(identity_provider.scope).to eq(:write)
          end
        end
      end
    end
  end
end
