require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::OrphanDisksController do
      include Rack::Test::Methods

      subject(:app) { linted_rack_app(described_class.new(config)) }
      let(:config) { Config.load_hash(SpecHelper.spec_get_director_config) }

      let(:orphaned_at) { Time.now.utc }

      before do
        App.new(config)
      end

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
          body = JSON.parse(last_response.body)

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
          expect(Jobs::DeleteOrphanDisks).to receive(:enqueue)
            .with('admin', ['random-disk-cid-1'], kind_of(JobQueue))
            .and_call_original
          delete '/random-disk-cid-1'
          expect_redirect_to_queued_task(last_response)
        end
      end
    end
  end
end
