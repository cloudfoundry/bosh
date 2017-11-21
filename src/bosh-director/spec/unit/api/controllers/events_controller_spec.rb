require 'spec_helper'
require 'timecop'
require 'rack/test'
require 'bosh/director/api/controllers/events_controller'

module Bosh::Director
  module Api
    describe Controllers::EventsController do
      include Rack::Test::Methods

      subject(:app) { linted_rack_app(described_class.new(config)) }

      let(:config) { Config.load_hash(SpecHelper.spec_get_director_config) }
      let(:timestamp) { Time.now }

      before do
        App.new(config)
      end

      describe 'get' do
        before do
          Timecop.freeze(timestamp)
        end

        after do
          Timecop.return
        end

        def make_events(count)
          (1..count).each do |i|
            Models::Event.make(:timestamp => timestamp + (i * 1.second))
          end
        end

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
            body = JSON.parse(last_response.body)

            expect(body.size).to eq(2)

            expected = [
              {'id' => '2',
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
            expect(JSON.parse(last_response.body)).to eq(expected)
          end

          it 'returns 200 events' do
            basic_authorize 'admin', 'admin'
            make_events(250)

            get '/'
            body = JSON.parse(last_response.body)

            expect(body.size).to eq(200)
            response_ids = body.map { |e| e['id'].to_i }
            expected_ids = *(53..252)
            expect(response_ids).to eq(expected_ids.reverse)
          end
        end

        context 'event' do
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

          it 'returns event' do
            basic_authorize 'admin', 'admin'

            get '/2'

            expect(JSON.parse(last_response.body)).to eq(
              {'id' => '2',
                'parent_id' => '1',
                'timestamp' => timestamp.to_i,
                'user' => 'test',
                'action' => 'create',
                'object_type' => 'deployment',
                'object_name' => 'depl1',
                'task' => '2',
                'context' => {}
              })
          end

          it 'returns an error' do
            basic_authorize 'admin', 'admin'

            get '/3'

            expect(last_response.status).to eq(404)
            expect(last_response.body).to eq('Event not found')
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

        context 'when user is specified' do
          before do
            basic_authorize 'admin', 'admin'
            Models::Event.make('user' => 'admin')
            Models::Event.make('user' => 'user')
          end

          it 'returns a filtered list of events' do
            get '?user=admin'
            events = JSON.parse(last_response.body)
            expect(events.size).to eq(1)
            expect(events[0]['user']).to eq('admin')
          end
        end

        context 'when action is specified' do
          before do
            basic_authorize 'admin', 'admin'
            Models::Event.make('action' => 'delete')
            Models::Event.make('action' => 'update')
          end

          it 'returns a filtered list of events' do
            get '?action=delete'
            events = JSON.parse(last_response.body)
            expect(events.size).to eq(1)
            expect(events[0]['action']).to eq('delete')
          end
        end

        context 'when object_type is specified' do
          before do
            basic_authorize 'admin', 'admin'
            Models::Event.make('object_type' => 'deployment')
            Models::Event.make('object_type' => 'instance')
          end

          it 'returns a filtered list of events' do
            get '?object_type=deployment'
            events = JSON.parse(last_response.body)
            expect(events.size).to eq(1)
            expect(events[0]['object_type']).to eq('deployment')
          end
        end

        context 'when object_name is specified' do
          before do
            basic_authorize 'admin', 'admin'
            Models::Event.make('object_name' => 'fake_name')
            Models::Event.make('object_name' => 'another_name')
          end

          it 'returns a filtered list of events' do
            get '?object_name=fake_name'
            events = JSON.parse(last_response.body)
            expect(events.size).to eq(1)
            expect(events[0]['object_name']).to eq('fake_name')
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
              get '?instance=job/5&task=4&deployment=name&before_id=3'
              events = JSON.parse(last_response.body)
              expect(events.size).to eq(1)
              expect(events[0]['instance']).to eq('job/5')
              expect(events[0]['task']).to eq('4')
              expect(events[0]['deployment']).to eq('name')
            end
          end

          context 'when user, action, object_name and object_type are specified' do
            before do
              Models::Event.make('user' => 'admin')
              Models::Event.make('user' => 'admin', 'action' => 'update', 'object_name' => 'test', 'object_type' => 'deployment')
              Models::Event.make('user' => 'admin', 'action' => 'update', 'object_name' => 'test', 'object_type' => 'deployment1')
              Models::Event.make('object_name' => 'something')
              Models::Event.make('object_type' => 'deployment')
            end

            it 'returns the ended results' do
              get '?user=admin&action=update&object_name=test&object_type=deployment'
              events = JSON.parse(last_response.body)
              expect(events.size).to eq(1)
              expect(events[0]['user']).to eq('admin')
              expect(events[0]['action']).to eq('update')
              expect(events[0]['object_name']).to eq('test')
              expect(events[0]['object_type']).to eq('deployment')
            end
          end


          context 'when before and after are specified' do
            before do
              make_events(20)
            end

            it 'returns the correct results' do
              get "?before_time=#{URI.encode(Models::Event.order(:timestamp).all[16].timestamp.to_s)}&after_time=#{URI.encode(Models::Event.order(:timestamp).all[14].timestamp.to_s)}"
              events = JSON.parse(last_response.body)
              expect(events.size).to eq(1)
              expect(events.first['id']).to eq('16')
            end
          end

          context 'when after and before_id are specified' do
            before do
              make_events(20)
            end

            it 'returns the correct result' do
              get "?before_id=15&after_time=#{URI.encode(Models::Event.order(:timestamp).all[12].timestamp.to_s)}"
              events = JSON.parse(last_response.body)
              expect(events.size).to eq(1)
              expect(events.first['id']).to eq('14')
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
            make_events(210)
            expect(Models::Event.count).to eq(210)

            get "?before_time=#{URI.encode(Models::Event.order(:timestamp).all[201].timestamp.to_s)}"
            events = JSON.parse(last_response.body)

            expect(events.size).to eq(200) # 200 limit
            response_ids = events.map { |e| e['id'].to_i }
            expected_ids = *(2..201) # exclusive
            expect(response_ids).to eq(expected_ids.reverse)
          end

          it 'supports date as Integer' do
            make_events(10)
            get "?before_time=#{Models::Event.order(:timestamp).all[1].timestamp.to_i}"
            events = JSON.parse(last_response.body)

            expect(events.size).to eq(1)
            expect(events.first['id']).to eq('1')
          end

          it 'supports date as specified in the event table' do
            make_events(10)
            get "?before_time=#{URI.encode(Models::Event.order(:timestamp).all[1].timestamp.utc.strftime('%a %b %d %H:%M:%S %Z %Y'))}"
            events = JSON.parse(last_response.body)

            expect(events.size).to eq(1)
            expect(events.first['id']).to eq('1')
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
            make_events(210)
            expect(Models::Event.count).to eq(210)

            get "?after_time=#{URI.encode(Models::Event.order(:timestamp).all[9].timestamp.to_s)}"
            events = JSON.parse(last_response.body)

            expect(events.size).to eq(200)
            response_ids = events.map { |e| e['id'].to_i }
            expected_ids = *(11..210)
            expect(response_ids).to eq(expected_ids.reverse)
          end

          it 'supports date as Integer' do
            make_events(10)
            get "?after_time=#{Models::Event.order(:timestamp).all[8].timestamp.to_i}"
            events = JSON.parse(last_response.body)

            expect(events.size).to eq(1)
            expect(events.first['id']).to eq('10')
          end

          it 'supports date as specified in the event table' do
            make_events(10)
            get "?after_time=#{URI.encode(Models::Event.order(:timestamp).all[8].timestamp.utc.strftime('%a %b %d %H:%M:%S %Z %Y'))}"
            events = JSON.parse(last_response.body)

            expect(events.size).to eq(1)
            expect(events.first['id']).to eq('10')
          end
        end

        context 'when before_id is specified' do
          before do
            basic_authorize 'admin', 'admin'
          end

          it 'returns a list of events' do
            make_events(250)

            get '?before_id=230'
            events = JSON.parse(last_response.body)

            expect(events.size).to eq(200)
            response_ids = events.map { |e| e['id'].to_i }
            expected_ids = *(30..229)
            expect(response_ids).to eq(expected_ids.reverse)
          end

          it 'returns correct number of events' do
            make_events(250)
            Models::Event.filter(Sequel.lit("id > ?", 200)).delete

            make_events(50)

            get '?before_id=270'
            body = JSON.parse(last_response.body)

            expect(body.size).to eq(200)
            response_ids = body.map { |e| e['id'].to_i }
            expected_ids = [*20..200, *251..269]
            expect(response_ids).to eq(expected_ids.reverse)
          end

          context 'when number of returned events is less than EVENT_LIMIT' do
            it 'returns empty list if before_id < minimal id' do
              make_events(10)
              Models::Event.filter(Sequel.lit("id <  ?", 5)).delete
              get '?before_id=4'
              body = JSON.parse(last_response.body)

              expect(last_response.status).to eq(200)
              expect(body.size).to eq(0)
            end

            it 'returns a list of events before_id' do
              make_events(10)
              get '?before_id=3'

              body = JSON.parse(last_response.body)
              response_ids = body.map { |e| e['id'] }

              expect(last_response.status).to eq(200)
              expect(body.size).to eq(2)
              expect(response_ids).to eq(['2', '1'])
            end
          end
        end
      end

      describe 'post' do
        let(:action) { 'create' }
        let(:context) { {'information' => 'blah blah'} }
        let(:payload) {
          {
            action: action,
            object_type: 'deployment',
            object_name: 'depl1',
            deployment: 'new_deployment',
            instance: 'new_instance',
            error: 'some error',
            context: context
          }
        }

        def perform
          post '/',
            JSON.generate(payload),
            {'CONTENT_TYPE' => 'application/json'}
        end

        context 'authenticated access' do
          before { authorize 'admin', 'admin' }

          it 'stores event' do
            expect { perform }.not_to raise_exception
            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq('')
            event = Models::Event.first
            expect(event.id).to eq(1)
            expect(event.parent_id).to eq(nil)
            expect(event.user).to eq('admin')
            expect(event.action).to eq('create')
            expect(event.object_type).to eq('deployment')
            expect(event.object_name).to eq('depl1')
            expect(event.task).to eq(nil)
            expect(event.instance).to eq('new_instance')
            expect(event.error).to eq('some error')
            expect(event.context).to eq({'information' => 'blah blah'})
          end

          context 'when timestamp is specified' do
            let(:timestamp) { '1479673560' }
            let(:payload) {
              {
                action: action,
                timestamp: timestamp,
                object_type: 'deployment',
                object_name: 'depl1',
                deployment: 'new_deployment',
                instance: 'new_instance',
                error: 'some error',
                context: context
              }
            }
            it 'stores given timestamp' do
              perform
              expect(Models::Event.first.timestamp.to_i).to eq(timestamp.to_i)
            end

            context 'when timestamp format is wrong' do
              let(:timestamp) { 'wrong' }
              it 'retuns an error' do
                perform
                expect(last_response.status).to eq(400)
                expect(last_response.body).to eq("Invalid timestamp parameter: 'wrong' ")
              end
            end
          end

          context 'when context is specified not as hash' do
            let(:context) { 'something' }
            it 'stores given timestamp' do
              perform
              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)).to eq(
                'code' => 40000,
                'description' => 'Context must be a hash'
              )
            end
          end

          context 'when someting missing' do
            let(:action) { nil }
            it 'shows error' do
              perform
              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)).to eq(
                'code' => 40000,
                'description' => 'Action, object_type, object_name are required',
              )
            end
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
    end
  end
end
