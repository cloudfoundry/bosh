require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::OrphanNetworksController do
      include Rack::Test::Methods

      subject(:app) { linted_rack_app(described_class.new(config)) }
      let(:config) { Config.load_hash(SpecHelper.spec_get_director_config) }
      let(:created_at) { Time.now.utc - 60 }
      let(:orphaned_at) { Time.now.utc }

      before do
        App.new(config)
      end

      context 'orphan networks' do
        before do
          Models::Network.make(
            name: 'nw-1',
            type: 'manual',
            orphaned: true,
            created_at: created_at,
            orphaned_at: orphaned_at,
          )
          Models::Network.make(
            name: 'nw-2',
            type: 'manual',
            orphaned: true,
            created_at: created_at - 50,
            orphaned_at: orphaned_at - 50,
          )
          Models::Network.make(
            name: 'nw-3',
            type: 'manual',
            orphaned: false,
            created_at: created_at,
            orphaned_at: orphaned_at,
          )
          basic_authorize 'admin', 'admin'
        end

        it 'returns a list of orphaned networks' do
          get '/'

          expect(last_response.status).to eq(200)
          body = JSON.parse(last_response.body)

          expect(body.size).to eq(2)

          expect(body).to include(
            hash_including(
              'name' => 'nw-2',
              'type' => 'manual',
              'created_at' => (created_at - 50).to_s,
              'orphaned_at' => (orphaned_at - 50).to_s,
            ),
          )

          expect(body).to include(
            hash_including(
              'name' => 'nw-1',
              'type' => 'manual',
              'created_at' => created_at.to_s,
              'orphaned_at' => orphaned_at.to_s,
            ),
          )
        end

        it 'deletes an orphan network' do
          expect(Jobs::DeleteOrphanNetworks).to receive(:enqueue)
            .with('admin', ['nw-1'], kind_of(JobQueue))
            .and_call_original
          delete '/nw-1'
          expect_redirect_to_queued_task(last_response)
        end
      end
    end
  end
end
