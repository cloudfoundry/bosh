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
            'timestamp' => timestamp,
            'user' => 'test',
            'action' => 'create',
            'object_type' => 'deployment',
            'object_name' => 'depl1',
            'task' => '1'
          )
          Models::Event.make(
            'parent_id' => 1,
            'timestamp' => timestamp,
            'user' => 'test',
            'action' => 'create',
            'object_type' => 'deployment',
            'object_name' => 'depl1',
            'task' => '2',
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

          expected = [
            { 'id' => '2',
              'parent_id' => '1',
              'timestamp' => timestamp.to_i,
              'user' => 'test',
              'action' => 'create',
              'object_type' => 'deployment',
              'object_name' => 'depl1',
              'task' => '2',
              'context' => {}
            },
            {
              'id' => '1',
              'timestamp' => timestamp.to_i,
              'user' => 'test',
              'action' => 'create',
              'object_type' => 'deployment',
              'object_name' => 'depl1',
              'task' => '1',
              'context' => {}
            }
          ]
          expect(Yajl::Parser.parse(last_response.body)).to eq(expected)
        end
      end

      context 'when before_id is specified' do
        before do
          basic_authorize 'admin', 'admin'
        end

        it 'returns a list of events' do
          (1..250).each do |i|
            Models::Event.make
          end

          get '?before_id=230'
          body = Yajl::Parser.parse(last_response.body)

          expect(body.size).to eq(200)
          response_ids = body.map { |e| e['id'].to_i }
          expected_ids = *(30..229)
          expect(response_ids).to eq(expected_ids.reverse)
        end

        it 'returns correct number of events' do
          (1..250).each do |i|
            Models::Event.make
          end
          Models::Event.filter("id > ?", 200).delete

          (1..50).each do |i|
            Models::Event.make
          end

          get '?before_id=270'
          body = Yajl::Parser.parse(last_response.body)

          expect(body.size).to eq(200)
          response_ids = body.map { |e| e['id'].to_i }
          expected_ids = [*20..200, *251..269]
          expect(response_ids).to eq(expected_ids.reverse)
        end

        context 'when number of returned events is less than EVENT_LIMIT' do
          it 'returns empty list if before_id < minimal id' do
            (1..10).each do |i|
              Models::Event.make
            end
            Models::Event.filter("id <  ?", 5).delete
            get '?before_id=4'
            body = Yajl::Parser.parse(last_response.body)

            expect(last_response.status).to eq(200)
            expect(body.size).to eq(0)
          end

          it 'returns a list of events before_id' do
            (1..10).each do |i|
              Models::Event.make
            end
            get '?before_id=3'

            body         = Yajl::Parser.parse(last_response.body)
            response_ids = body.map { |e| e['id'] }

            expect(last_response.status).to eq(200)
            expect(body.size).to eq(2)
            expect(response_ids).to eq(['2', '1'])
          end
        end
      end
    end
  end
end
