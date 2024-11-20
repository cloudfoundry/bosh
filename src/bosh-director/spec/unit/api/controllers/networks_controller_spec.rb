require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::NetworksController do
      include Rack::Test::Methods

      subject(:app) { linted_rack_app(described_class.new(config)) }
      let(:config) { Config.load_hash(SpecHelper.director_config_hash) }
      let(:created_at) { Time.now.utc - 120 }
      let(:orphaned_at) { Time.now.utc }

      before do
        App.new(config)
      end

      context 'orphan networks' do
        before do
          FactoryBot.create(:models_network,
            name: 'nw-1',
            type: 'manual',
            created_at: created_at,
            orphaned_at: orphaned_at,
            orphaned: true,
          )
          FactoryBot.create(:models_network,
            name: 'nw-2',
            type: 'manual',
            created_at: created_at - 10,
            orphaned_at: orphaned_at - 10,
            orphaned: true,
          )
          FactoryBot.create(:models_network,
            name: 'nw-3',
            type: 'manual',
            created_at: created_at - 20,
            orphaned_at: orphaned_at - 20,
            orphaned: false,
          )

          basic_authorize 'admin', 'admin'
        end

        it 'returns a list of orphaned networks' do
          get '/?orphaned=true'

          expect(last_response.status).to eq(200)
          body = JSON.parse(last_response.body)

          expect(body.size).to eq(2)

          expect(body).to include(
            hash_including(
              'name' => 'nw-2',
              'type' => 'manual',
              'created_at' => (created_at - 10).to_s,
              'orphaned_at' => (orphaned_at - 10).to_s,
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

        it 'returns a 500 status when orphaned parameter is absent' do
          get '/'

          expect(last_response.status).to eq(500)
        end

        it 'returns a 500 status when orphaned parameter is false' do
          get '/'

          expect(last_response.status).to eq(500)
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
