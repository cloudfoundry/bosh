require 'spec_helper'
require 'rack/test'
require 'bosh/director/api/controllers/events_controller'

module Bosh::Director
  module Api
    describe Controllers::EventsController do
      include Rack::Test::Methods

      subject(:app) { described_class.new(config) }
      let(:config) { Config.load_hash(Psych.load(spec_asset('test-director-config.yml'))) }
      let(:temp_dir) { Dir.mktmpdir }
      let(:timestamp) { Time.now }

      before do
        App.new(config)
      end

      after { FileUtils.rm_rf(temp_dir) }

      context 'events' do
        before do
          Models::Event.make(
              "target_type"  => "deployment",
              "target_name"  => "simple",
              "event_action" => "create",
              "event_state"  => "started",
              "event_result" => "running",
              "task_id"      => 1,
              "timestamp"    => timestamp
          )
          Models::Event.make(
              "target_type"  => "deployment",
              "target_name"  => "simple",
              "event_action" => "create",
              "event_state"  => "done",
              "event_result" => "/deployment/simple",
              "task_id"      => 1,
              "timestamp"    => timestamp
          )
        end

        it 'requires auth' do
          get '/'
          expect(last_response.status).to eq(401)
        end


        it 'returns a list of events' do
          basic_authorize 'admin', 'admin'
          get '/'

          expect(last_response.status).to eq(200)
          body = Yajl::Parser.parse(last_response.body)

          expect(body.size).to eq(2)

          expect(body.first['target_type']).to eq('deployment')
          expect(body.first['target_name']).to eq('simple')
          expect(body.first['event_action']).to eq('create')
          expect(body.first['event_state']).to eq('started')
          expect(body.first['event_result']).to eq('running')
          expect(body.first['task_id']).to eq(1)
          expect(body.first['timestamp']).to eq(timestamp.to_i)

          expect(body.last['target_type']).to eq('deployment')
          expect(body.last['target_name']).to eq('simple')
          expect(body.last['event_action']).to eq('create')
          expect(body.last['event_state']).to eq('done')
          expect(body.last['event_result']).to eq('/deployment/simple')
          expect(body.last['task_id']).to eq(1)
          expect(body.last['timestamp']).to eq(timestamp.to_i)
        end
      end
    end
  end
end
