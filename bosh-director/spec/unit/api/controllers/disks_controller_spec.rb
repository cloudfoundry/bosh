require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::DisksController do
      include Rack::Test::Methods

      subject(:app) { described_class.new(config) }
      let(:config) { Config.load_hash(test_config) }

      let(:temp_dir) { Dir.mktmpdir }
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

      let(:orphaned_at) { Time.now.utc }

      before do
        App.new(config)
      end

      after { FileUtils.rm_rf(temp_dir) }

      context 'orphan disks' do
        before do
          Models::OrphanDisk.make(
            disk_cid: 'random-disk-cid-1',
            instance_name: 'fake-name-1',
            size: 10,
            availability_zone: 'az1',
            deployment_name: 'fake-deployment',
            created_at: orphaned_at,
            cloud_properties: {'cloud' => 'properties'}
          )
          Models::OrphanDisk.make(
            disk_cid: 'random-disk-cid-2',
            instance_name: 'fake-name-2',
            deployment_name: 'fake-deployment',
            created_at: orphaned_at,
          )

          basic_authorize 'admin', 'admin'
        end
        it 'returns a list of orphaned disks' do
          get '/'

          expect(last_response.status).to eq(200)
          body = Yajl::Parser.parse(last_response.body)

          expect(body.size).to eq(2)

          expect(body.first['disk_cid']).to eq('random-disk-cid-1')
          expect(body.first['size']).to eq(10)
          expect(body.first['az']).to eq('az1')
          expect(body.first['instance_name']).to eq('fake-name-1')
          expect(body.first['orphaned_at']).to eq("#{orphaned_at}")
          expect(body.first['cloud_properties']).to eq({'cloud' => 'properties'})

          expect(body.last['disk_cid']).to eq('random-disk-cid-2')
          expect(body.last['size']).to be_nil
          expect(body.last['az']).to be_nil
          expect(body.last['instance_name']).to eq('fake-name-2')
          expect(body.last['orphaned_at']).to eq("#{orphaned_at}")
          expect(body.last['cloud_properties']).to be_empty
        end

        it 'deletes an orphan disk' do
          delete '/random-disk-cid-1'

          expect_redirect_to_queued_task(last_response)
        end
      end

      context 'put /disks/diskcid/attachments' do
        it 'requires auth' do
          put '/vol-af4a3e40/attachments?deployment=foo&job=dea&instance_id=17f01a35'
          expect(last_response.status).to eq(401)
        end

        it 'queues an attach disk job' do
          basic_authorize('admin', 'admin')
          expect(Jobs::AttachDisk).to receive(:enqueue)
                                        .with('admin', 'foo', 'dea', '17f01a35', 'vol-af4a3e40', kind_of(JobQueue))
                                        .and_call_original

          put '/vol-af4a3e40/attachments?deployment=foo&job=dea&instance_id=17f01a35'
          expect_redirect_to_queued_task(last_response)
        end
      end
    end
  end
end
