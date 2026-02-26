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

        context 'when user has bosh.dynamic_disks.update scope' do
          before { basic_authorize('dynamic-disks-updater', 'dynamic-disks-updater') }

          it 'enqueues a ProvideDynamicDisk task' do
            expect_any_instance_of(Bosh::Director::JobQueue).to receive(:enqueue).with(
              'dynamic-disks-updater',
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

      describe 'DELETE', '/:disk_name' do
        context 'when user is reader' do
          before { basic_authorize('reader', 'reader') }

          it 'forbids access' do
            expect(delete('/disk_name').status).to eq(401)
          end
        end

        context 'when user has bosh.dynamic_disks.update scope' do
          before { basic_authorize('dynamic-disks-updater', 'dynamic-disks-updater') }

          it 'forbids access' do
            expect(delete('/disk_name').status).to eq(401)
          end
        end

        context 'when user has bosh.dynamic_disks.delete scope' do
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