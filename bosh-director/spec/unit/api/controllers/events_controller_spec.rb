require 'spec_helper'
require 'rack/test'
require 'bosh/director/api/controllers/events_controller'

module Bosh::Director
  module Api
    describe Controllers::EventsController do
      include Rack::Test::Methods

      subject(:app) { described_class.new(config) }
      let(:config) { Config.load_hash(SpecHelper.spec_get_director_config) }
      let(:timestamp) { Time.at(1465372161.629570) }
      let (:all_expected_ids) do
        expected_ids = []
        (1..270).each do |i|
          expected_ids << (timestamp + i).to_f.to_s
        end
        expected_ids
      end

      before do
        App.new(config)
      end

      context 'events' do
        before do
          Models::Event.make(
            'id' => timestamp,
            'user' => 'test',
            'action' => 'create',
            'object_type' => 'deployment',
            'object_name' => 'depl1',
            'task' => '1'
          )
          Models::Event.make(
            'id' => timestamp + 1,
            'parent_id' => timestamp,
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
          body = JSON.parse(last_response.body)

          expect(body.size).to eq(2)

          expected = [
            { 'id' => (timestamp + 1).to_f.to_s,
              'parent_id' => timestamp.to_f.to_s,
              'timestamp' => (timestamp + 1).to_i,
              'user' => 'test',
              'action' => 'create',
              'object_type' => 'deployment',
              'object_name' => 'depl1',
              'task' => '2',
              'context' => {}
            },
            {
              'id' => timestamp.to_f.to_s,
              'timestamp' => timestamp.to_i,
              'user' => 'test',
              'action' => 'create',
              'object_type' => 'deployment',
              'object_name' => 'depl1',
              'task' => '1',
              'context' => {}
            }
          ]
          expect(JSON.parse(last_response.body)).to eq(expected)
        end

        it 'returns 200 events' do
          basic_authorize 'admin', 'admin'
          (1..250).each do |i|
            Models::Event.make('id' => timestamp + i + 2)
          end

          get '/'
          body = JSON.parse(last_response.body)
          expect(body.size).to eq(200)
          response_ids = body.map { |e| e['id'] }
          expected_ids = all_expected_ids.slice(52, 200)
          expect(response_ids).to eq(expected_ids.reverse)
        end
      end

      context 'when deployment is specified' do
        before do
          basic_authorize 'admin', 'admin'
          Models::Event.make('deployment' => 'name')
          Models::Event.make('deployment' => 'not the droid we are looking for')
        end

        it 'returns a filtered list of events' do
          get '?deployment=name'
          events = JSON.parse(last_response.body)
          expect(events.size).to eq(1)
          expect(events[0]['deployment']).to eq('name')
        end
      end

      context 'when task is specified' do
        before do
          basic_authorize 'admin', 'admin'
          Models::Event.make('task' => 4)
          Models::Event.make('task' => 5)
        end

        it 'returns a filtered list of events' do
          get '?task=4'
          events = JSON.parse(last_response.body)
          expect(events.size).to eq(1)
          expect(events[0]['task']).to eq('4')
        end
      end

      context 'when instance is specified' do
        before do
          basic_authorize 'admin', 'admin'
          Models::Event.make('instance' => 'job/4')
          Models::Event.make('instance' => 'job/5')
        end

        it 'returns a filtered list of events' do
          get '?instance=job/4'
          events = JSON.parse(last_response.body)
          expect(events.size).to eq(1)
          expect(events[0]['instance']).to eq('job/4')
        end
      end

      context 'when several filters are specified' do
        before do
          basic_authorize 'admin', 'admin'
        end

        context 'when before_id, instance, deployment and task are specified' do
          before do
            Models::Event.make('instance' => 'job/4')
            Models::Event.make('instance' => 'job/5', 'task' => 4, 'deployment' => 'name')
            Models::Event.make('task' => 5)
            Models::Event.make('deployment' => 'not the droid we are looking for')
          end

          it 'returns the anded results' do
            get "?instance=job/5&task=4&deployment=name&before_id=#{Models::Event.all[3].id.to_f}"
            events = JSON.parse(last_response.body)
            expect(events.size).to eq(1)
            expect(events[0]['instance']).to eq('job/5')
            expect(events[0]['task']).to eq('4')
            expect(events[0]['deployment']).to eq('name')
          end
        end

        context 'when before and after are specified' do
          before do
            (1..20).each do |i|
              Models::Event.make(:id => timestamp + i)
            end
          end

          it 'returns the correct results' do
            get "?before_time=#{URI.encode(Models::Event.all[16].id.to_i.to_s)}&after_time=#{URI.encode(Models::Event.all[14].id.to_i.to_s)}"
            events = JSON.parse(last_response.body)
            expect(events.size).to eq(1)
            expect(events.first['id']).to eq(Models::Event.all[15].id.to_f.to_s)
          end
        end

        context 'when after and before_id are specified' do
          before do
            (1..20).each do |i|
              Models::Event.make(:id => timestamp + i)
            end
          end

          it 'returns the correct result' do
            get "?before_id=#{Models::Event.all[14].id.to_f}&after_time=#{URI.encode(Models::Event.all[12].id.to_s)}"
            events = JSON.parse(last_response.body)
            expect(events.size).to eq(1)
            expect(events.first['id']).to eq(Models::Event.all[13].id.to_f.to_s)
          end
        end
      end

      context 'when before is specified' do
        before do
          basic_authorize 'admin', 'admin'
        end

        it 'returns STATUS 400 if before has wrong format' do
          get "?before_time=Wrong"
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq("Invalid before parameter: 'Wrong' ")
        end

        it 'returns a list of events' do
          (1..210).each do |i|
            Models::Event.make(:id => timestamp + i)
          end
          get "?before_time=#{URI.encode(Time.at(Models::Event.all[201].id).to_s)}"
          events = JSON.parse(last_response.body)

          expect(events.size).to eq(200) # 200 limit
          response_ids = events.map { |e| e['id'] }
          expected_ids = all_expected_ids.slice(1, 200)
          expect(response_ids).to eq(expected_ids.reverse)
        end

        it 'supports date as Integer' do
          (1..10).each do |i|
            Models::Event.make(:id => timestamp + i)
          end
          get "?before_time=#{Models::Event.all[1].id.to_i}"
          events = JSON.parse(last_response.body)

          expect(events.size).to eq(1)
          expect(events.first['id']).to eq(Models::Event.first.id.to_f.to_s)
        end

        it 'supports date as specified in the event table' do
          (1..10).each do |i|
            Models::Event.make(:id => timestamp + i)
          end
          get "?before_time=#{URI.encode(Models::Event.all[1].id.utc.strftime('%a %b %d %H:%M:%S %Z %Y'))}"
          events = JSON.parse(last_response.body)

          expect(events.size).to eq(1)
          expect(events.first['id']).to eq(Models::Event.first.id.to_f.to_s)
        end
      end

      context 'when after is specified' do
        before do
          basic_authorize 'admin', 'admin'
        end

        it 'returns STATUS 400 if after has wrong format' do
          get "?after_time=Wrong"
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq("Invalid after parameter: 'Wrong' ")
        end

        it 'returns a list of events' do
          (1..210).each do |i|
            Models::Event.make(:id => timestamp + i)
          end
          get "?after_time=#{URI.encode(Models::Event.all[9].id.to_s)}"
          events = JSON.parse(last_response.body)

          expect(events.size).to eq(200)
          response_ids = events.map { |e| e['id'] }
          expected_ids = all_expected_ids.slice(10, 200)
          expect(response_ids).to eq(expected_ids.reverse)
        end

        it 'supports date as Integer' do
          (1..10).each do |i|
            Models::Event.make(:id => timestamp + i)
          end
          get "?after_time=#{Models::Event.all[8].id.to_i}"
          events = JSON.parse(last_response.body)

          expect(events.size).to eq(1)
          expect(events.first['id']).to eq(Models::Event.all[9].id.to_f.to_s)
        end

        it 'supports date as specified in the event table' do
          (1..10).each do |i|
            Models::Event.make(:id => timestamp + i)
          end
          get "?after_time=#{URI.encode(Models::Event.all[8].id.utc.strftime('%a %b %d %H:%M:%S %Z %Y'))}"
          events = JSON.parse(last_response.body)

          expect(events.size).to eq(1)
          expect(events.first['id']).to eq(Models::Event.all[9].id.to_f.to_s)
        end
      end

      context 'when before_id is specified' do
        before do
          basic_authorize 'admin', 'admin'
        end

        it 'returns a list of events' do
          (1..250).each do |i|
            Models::Event.make(:id => timestamp + i)
          end

          get "?before_id=#{Models::Event.all[230].id.to_f}"
          events = JSON.parse(last_response.body)

          expect(events.size).to eq(200)
          response_ids = events.map { |e| e['id'] }
          expected_ids = all_expected_ids.slice(30, 200)
          expect(response_ids).to eq(expected_ids.reverse)
        end

        it 'returns correct number of events' do
          (1..250).each do |i|
            Models::Event.make(:id => timestamp + i)
          end
          Models::Event.filter("id > ?", Time.at(Models::Event.all[200].id)).delete

          (1..50).each do |i|
            Models::Event.make(:id => timestamp + 250 + i)
          end

          get "?before_id=#{Models::Event.all[220].id.to_f}"
          body = JSON.parse(last_response.body)

          expect(body.size).to eq(200)
          response_ids = body.map { |e| e['id'] }
          expected_ids =  all_expected_ids.slice(20..200) + all_expected_ids.slice(250..268)
          expect(response_ids).to eq(expected_ids.reverse)
        end

        context 'when number of returned events is less than EVENT_LIMIT' do
          it 'returns empty list if before_id < minimal id' do
            (1..10).each do |i|
              Models::Event.make
            end
            before_id = Models::Event.all[4].id.to_f
            Models::Event.filter("id < ?", Time.at(Models::Event.all[5].id)).delete
            get "?before_id=#{before_id}"
            body = JSON.parse(last_response.body)

            expect(last_response.status).to eq(200)
            expect(body.size).to eq(0)
          end

          it 'returns a list of events before_id' do
            (1..10).each do |i|
              Models::Event.make
            end
            get "?before_id=#{Models::Event.all[2].id.to_f}"

            body         = JSON.parse(last_response.body)
            response_ids = body.map { |e| e['id'] }

            expect(last_response.status).to eq(200)
            expect(body.size).to eq(2)
            expect(response_ids).to eq([Models::Event.all[1].id.to_f.to_s, Models::Event.all[0].id.to_f.to_s])
          end
        end
      end
    end
  end
end
