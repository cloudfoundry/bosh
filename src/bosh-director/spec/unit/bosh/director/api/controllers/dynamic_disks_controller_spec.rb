require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::DynamicDisksController do
      include Rack::Test::Methods

      subject(:app) { linted_rack_app(described_class.new(config)) }
      let(:config) do
        config = Config.load_hash(SpecHelper.director_config_hash)
        identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
        allow(config).to receive(:identity_provider).and_return(identity_provider)
        config
      end
      before { App.new(config) }

      let(:instance_id) { 'fake-instance-id' }
      let(:deployment_name) { 'fake-deployment' }
      let(:az) { 'z1' }
      let(:disk_pool_name) { 'fake_disk_pool_name' }
      let(:disk_name) { 'fake_disk_name' }
      let(:disk_size) { 1000 }
      let(:metadata) { { 'some-key' => 'some-value' } }

      describe 'POST', '/provide' do
        let(:content) do
          JSON.generate({
                          'instance_id' => instance_id,
                          'disk_pool_name' => disk_pool_name,
                          'disk_name' => disk_name,
                          'disk_size' => disk_size,
                          'metadata' => metadata
                        })
        end

        context 'when user is reader' do
          before { basic_authorize('reader', 'reader') }

          it 'forbids access' do
            expect(post('/provide', content, { 'CONTENT_TYPE' => 'application/json' }).status).to eq(401)
          end
        end

        context 'when user has both bosh.dynamic-disks.create and bosh.dynamic-disks.attach scopes' do
          before { authorize 'dynamic-disks-provider', 'dynamic-disks-provider' }

          it 'enqueues a ProvideDynamicDisk task' do
            expect_any_instance_of(Bosh::Director::JobQueue).to receive(:enqueue).with(
              'dynamic-disks-provider',
              Jobs::DynamicDisks::ProvideDynamicDisk,
              'provide dynamic disk',
              [instance_id, disk_name, disk_pool_name, disk_size, metadata],
            ).and_call_original

            post '/provide', content, { 'CONTENT_TYPE' => 'application/json' }

            expect_redirect_to_queued_task(last_response)
          end
        end

        context 'when user has only bosh.dynamic-disks.create scope' do
          before { basic_authorize('dynamic-disks-creator', 'dynamic-disks-creator') }

          it 'forbids access' do
            expect(post('/provide', content, {'CONTENT_TYPE' => 'application/json'}).status).to eq(401)
          end
        end

        context 'user has admin permissions' do
          before { authorize 'admin', 'admin' }

          it 'enqueues a ProvideDynamicDisk task' do
            expect_any_instance_of(Bosh::Director::JobQueue).to receive(:enqueue).with(
              'admin',
              Jobs::DynamicDisks::ProvideDynamicDisk,
              'provide dynamic disk',
              [instance_id, disk_name, disk_pool_name, disk_size, metadata],
            ).and_call_original

            post '/provide', content, { 'CONTENT_TYPE' => 'application/json' }

            expect_redirect_to_queued_task(last_response)
          end

          context 'content is invalid' do
            context 'disk_pool_name is nil' do
              let(:disk_pool_name) { nil }

              it 'raises an error' do
                post '/provide', content, { 'CONTENT_TYPE' => 'application/json' }

                expect(last_response.status).to eq(400)
                expect(JSON.parse(last_response.body)).to eq(
                                                            'code' => 40000,
                                                            'description' => "Property 'disk_pool_name' value (nil) did not match the required type 'String'",
                                                          )
              end
            end

            context 'disk_pool_name is empty' do
              let(:disk_pool_name) { '' }

              it 'raises an error' do
                post '/provide', content, { 'CONTENT_TYPE' => 'application/json' }

                expect(last_response.status).to eq(400)
                expect(JSON.parse(last_response.body)).to eq(
                                                            'code' => 40002,
                                                            'description' => "'disk_pool_name' length (0) should be greater than 1",
                                                          )
              end
            end

            context 'disk_name is nil' do
              let(:disk_name) { nil }

              it 'raises an error' do
                post '/provide', content, { 'CONTENT_TYPE' => 'application/json' }

                expect(last_response.status).to eq(400)
                expect(JSON.parse(last_response.body)).to eq(
                                                            'code' => 40000,
                                                            'description' => "Property 'disk_name' value (nil) did not match the required type 'String'",
                                                          )
              end
            end

            context 'disk_name is empty' do
              let(:disk_name) { '' }

              it 'raises an error' do
                post '/provide', content, { 'CONTENT_TYPE' => 'application/json' }

                expect(last_response.status).to eq(400)
                expect(JSON.parse(last_response.body)).to eq(
                                                            'code' => 40002,
                                                            'description' => "'disk_name' length (0) should be greater than 1",
                                                          )
              end
            end

            context 'disk_size is empty' do
              let(:disk_size) { nil }

              it 'raises an error' do
                post '/provide', content, { 'CONTENT_TYPE' => 'application/json' }

                expect(last_response.status).to eq(400)
                expect(JSON.parse(last_response.body)).to eq(
                                                            'code' => 40000,
                                                            'description' => "Property 'disk_size' value (nil) did not match the required type 'Integer'",
                                                          )
              end
            end

            context 'disk_size is 0' do
              let(:disk_size) { 0 }

              it 'raises an error' do
                post '/provide', content, { 'CONTENT_TYPE' => 'application/json' }

                expect(last_response.status).to eq(400)
                expect(JSON.parse(last_response.body)).to eq(
                                                            'code' => 40002,
                                                            'description' => "'disk_size' value (0) should be greater than 1",
                                                          )
              end
            end
          end
        end
      end

      describe 'POST', '/:disk_name/detach' do
        context 'when user is reader' do
          before { basic_authorize('reader', 'reader') }

          it 'forbids access' do
            expect(post('/disk_name/detach').status).to eq(401)
          end
        end

        context 'when user has bosh.dynamic-disks.detach scope' do
          before { basic_authorize('dynamic-disks-detacher', 'dynamic-disks-detacher') }

          it 'enqueues a DetachDynamicDisk task' do
            expect_any_instance_of(Bosh::Director::JobQueue).to receive(:enqueue).with(
              'dynamic-disks-detacher',
              Jobs::DynamicDisks::DetachDynamicDisk,
              'detach dynamic disk',
              ['disk_name'],
            ).and_call_original

            post '/disk_name/detach'

            expect_redirect_to_queued_task(last_response)
          end
        end

        context 'user has admin permissions' do
          before { authorize 'admin', 'admin' }

          it 'enqueues a ProvideDynamicDisk task' do
            expect_any_instance_of(Bosh::Director::JobQueue).to receive(:enqueue).with(
              'admin',
              Jobs::DynamicDisks::DetachDynamicDisk,
              'detach dynamic disk',
              ['disk_name'],
            ).and_call_original

            post '/disk_name/detach'

            expect_redirect_to_queued_task(last_response)
          end
        end
      end

      describe 'GET', '/' do
        context 'when user is reader' do
          before { basic_authorize('reader', 'reader') }

          it 'forbids access' do
            expect(get('/').status).to eq(401)
          end
        end

        context 'when user has bosh.dynamic-disks.list scope' do
          before { basic_authorize('dynamic-disks-lister', 'dynamic-disks-lister') }

          context 'when there are no dynamic disks' do
            it 'returns an empty list' do
              get '/'
              expect(last_response.status).to eq(200)
              expect(JSON.parse(last_response.body)).to eq([])
            end
          end

          context 'when dynamic disks exist' do
            let!(:deployment) { FactoryBot.create(:models_deployment, name: 'my-deployment') }
            let!(:disk1) do
              FactoryBot.create(:models_dynamic_disk,
                name: 'disk-a',
                disk_cid: 'cid-a',
                deployment: deployment,
                size: 1024,
                disk_pool_name: 'large',
                metadata: { 'env' => 'prod' },
              )
            end
            let!(:disk2) do
              FactoryBot.create(:models_dynamic_disk,
                name: 'disk-b',
                disk_cid: 'cid-b',
                deployment: deployment,
                size: 2048,
                disk_pool_name: 'small',
              )
            end

            it 'returns all dynamic disks including disk_pool_name and metadata' do
              get '/'
              expect(last_response.status).to eq(200)
              body = JSON.parse(last_response.body)
              expect(body.size).to eq(2)
              expect(body).to include(hash_including(
                'name' => 'disk-a',
                'disk_cid' => 'cid-a',
                'deployment' => 'my-deployment',
                'size' => 1024,
                'disk_pool_name' => 'large',
                'metadata' => { 'env' => 'prod' },
              ))
              expect(body).to include(hash_including(
                'name' => 'disk-b',
                'disk_cid' => 'cid-b',
                'deployment' => 'my-deployment',
                'size' => 2048,
                'disk_pool_name' => 'small',
              ))
            end
          end
        end

        context 'when user has admin permissions' do
          before { authorize 'admin', 'admin' }

          it 'returns a list of dynamic disks' do
            get '/'
            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body)).to eq([])
          end
        end
      end

      describe 'POST', '/' do
        let(:content) do
          JSON.generate({
            'deployment_name' => deployment_name,
            'az'              => az,
            'disk_pool_name'  => disk_pool_name,
            'disk_name'       => disk_name,
            'disk_size'       => disk_size,
            'metadata'        => metadata,
          })
        end

        context 'when user is reader' do
          before { basic_authorize('reader', 'reader') }

          it 'forbids access' do
            expect(post('/', content, { 'CONTENT_TYPE' => 'application/json' }).status).to eq(401)
          end
        end

        context 'when user has bosh.dynamic-disks.create scope' do
          before { basic_authorize('dynamic-disks-creator', 'dynamic-disks-creator') }

          it 'enqueues a CreateDynamicDisk task' do
            expect_any_instance_of(Bosh::Director::JobQueue).to receive(:enqueue).with(
              'dynamic-disks-creator',
              Jobs::DynamicDisks::CreateDynamicDisk,
              'create dynamic disk',
              [deployment_name, az, disk_name, disk_pool_name, disk_size, metadata],
            ).and_call_original

            post '/', content, { 'CONTENT_TYPE' => 'application/json' }

            expect_redirect_to_queued_task(last_response)
          end
        end

        context 'when user has only bosh.dynamic-disks.attach scope (not create)' do
          before { basic_authorize('dynamic-disks-attacher', 'dynamic-disks-attacher') }

          it 'forbids access' do
            expect(post('/', content, { 'CONTENT_TYPE' => 'application/json' }).status).to eq(401)
          end
        end

        context 'when user has admin permissions' do
          before { authorize 'admin', 'admin' }

          it 'enqueues a CreateDynamicDisk task' do
            expect_any_instance_of(Bosh::Director::JobQueue).to receive(:enqueue).with(
              'admin',
              Jobs::DynamicDisks::CreateDynamicDisk,
              'create dynamic disk',
              [deployment_name, az, disk_name, disk_pool_name, disk_size, metadata],
            ).and_call_original

            post '/', content, { 'CONTENT_TYPE' => 'application/json' }

            expect_redirect_to_queued_task(last_response)
          end

          context 'when deployment_name is missing' do
            let(:deployment_name) { nil }

            it 'raises an error' do
              post '/', content, { 'CONTENT_TYPE' => 'application/json' }
              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)['description']).to include('deployment_name')
            end
          end

          context 'when az is missing' do
            let(:az) { nil }

            it 'raises an error' do
              post '/', content, { 'CONTENT_TYPE' => 'application/json' }
              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)['description']).to include('az')
            end
          end

          context 'when disk_name is nil' do
            let(:disk_name) { nil }

            it 'raises an error' do
              post '/', content, { 'CONTENT_TYPE' => 'application/json' }
              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)['description']).to include('disk_name')
            end
          end

          context 'when disk_size is 0' do
            let(:disk_size) { 0 }

            it 'raises an error' do
              post '/', content, { 'CONTENT_TYPE' => 'application/json' }
              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)['description']).to include('disk_size')
            end
          end
        end
      end

      describe 'POST', '/:disk_name/attach' do
        let(:content) { JSON.generate({ 'instance_id' => instance_id, 'metadata' => metadata }) }

        context 'when user is reader' do
          before { basic_authorize('reader', 'reader') }

          it 'forbids access' do
            expect(post('/disk_name/attach', content, { 'CONTENT_TYPE' => 'application/json' }).status).to eq(401)
          end
        end

        context 'when user has bosh.dynamic-disks.attach scope' do
          before { basic_authorize('dynamic-disks-attacher', 'dynamic-disks-attacher') }

          it 'enqueues an AttachDynamicDisk task' do
            expect_any_instance_of(Bosh::Director::JobQueue).to receive(:enqueue).with(
              'dynamic-disks-attacher',
              Jobs::DynamicDisks::AttachDynamicDisk,
              'attach dynamic disk',
              ['disk_name', instance_id, metadata],
            ).and_call_original

            post '/disk_name/attach', content, { 'CONTENT_TYPE' => 'application/json' }

            expect_redirect_to_queued_task(last_response)
          end
        end

        context 'when user has only bosh.dynamic-disks.create scope (not attach)' do
          before { basic_authorize('dynamic-disks-creator', 'dynamic-disks-creator') }

          it 'forbids access' do
            expect(post('/disk_name/attach', content, { 'CONTENT_TYPE' => 'application/json' }).status).to eq(401)
          end
        end

        context 'when user has admin permissions' do
          before { authorize 'admin', 'admin' }

          it 'enqueues an AttachDynamicDisk task' do
            expect_any_instance_of(Bosh::Director::JobQueue).to receive(:enqueue).with(
              'admin',
              Jobs::DynamicDisks::AttachDynamicDisk,
              'attach dynamic disk',
              ['disk_name', instance_id, metadata],
            ).and_call_original

            post '/disk_name/attach', content, { 'CONTENT_TYPE' => 'application/json' }

            expect_redirect_to_queued_task(last_response)
          end

          context 'when metadata is omitted from the body' do
            let(:content) { JSON.generate({ 'instance_id' => instance_id }) }

            it 'enqueues an AttachDynamicDisk task with nil metadata' do
              expect_any_instance_of(Bosh::Director::JobQueue).to receive(:enqueue).with(
                'admin',
                Jobs::DynamicDisks::AttachDynamicDisk,
                'attach dynamic disk',
                ['disk_name', instance_id, nil],
              ).and_call_original

              post '/disk_name/attach', content, { 'CONTENT_TYPE' => 'application/json' }

              expect_redirect_to_queued_task(last_response)
            end
          end

          context 'when instance_id is missing from the body' do
            let(:content) { JSON.generate({}) }

            it 'raises an error' do
              post '/disk_name/attach', content, { 'CONTENT_TYPE' => 'application/json' }
              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)['description']).to include("instance_id")
            end
          end
        end
      end

      describe 'DELETE', '/:disk_name' do
        context 'when user is reader' do
          before { basic_authorize('reader', 'reader') }

          it 'forbids access' do
            expect(delete('/disk_name').status).to eq(401)
          end
        end

        context 'when user has bosh.dynamic-disks.delete scope' do
          before { authorize 'dynamic-disks-deleter', 'dynamic-disks-deleter' }

          it 'enqueues a ProvideDynamicDisk task' do
            expect_any_instance_of(Bosh::Director::JobQueue).to receive(:enqueue).with(
              'dynamic-disks-deleter',
              Jobs::DynamicDisks::DeleteDynamicDisk,
              'delete dynamic disk',
              ['disk_name'],
            ).and_call_original

            delete '/disk_name'

            expect_redirect_to_queued_task(last_response)
          end
        end

        context 'user has admin permissions' do
          before { authorize 'admin', 'admin' }

          it 'enqueues a ProvideDynamicDisk task' do
            expect_any_instance_of(Bosh::Director::JobQueue).to receive(:enqueue).with(
              'admin',
              Jobs::DynamicDisks::DeleteDynamicDisk,
              'delete dynamic disk',
              ['disk_name'],
            ).and_call_original

            delete '/disk_name'

            expect_redirect_to_queued_task(last_response)
          end
        end
      end
    end
  end
end