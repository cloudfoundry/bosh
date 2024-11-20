require 'spec_helper'
require 'rack/test'
require 'bosh/director/api/controllers/events_controller'

module Bosh::Director
  module Api
    describe Controllers::EventsController do
      include Rack::Test::Methods

      subject(:app) { linted_rack_app(described_class.new(config)) }

      let(:config) { Config.load_hash(SpecHelper.director_config_hash) }
      let(:timestamp) { Time.now }

      before do
        App.new(config)
      end

      describe 'get' do
        before do
          Timecop.freeze(timestamp)
        end

        def make_events(count)
          (1..count).each do |i|
            FactoryBot.create(:models_event, timestamp: timestamp + (i * 1.second))
          end
        end

        context 'events' do
          let!(:event1) do
            FactoryBot.create(:models_event,
              timestamp: timestamp,
              user: 'test',
              action: 'create',
              object_type: 'deployment',
              object_name: 'depl1',
              task: '1',
            )
          end

          let!(:event2) do
            FactoryBot.create(:models_event,
              parent_id: event1.id,
              timestamp: timestamp,
              user: 'test',
              action: 'create',
              object_type: 'deployment',
              object_name: 'depl1',
              task: '2',
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
              {
                'id' => event2.id.to_s,
                'parent_id' => event1.id.to_s,
                'timestamp' => timestamp.to_i,
                'user' => 'test',
                'action' => 'create',
                'object_type' => 'deployment',
                'object_name' => 'depl1',
                'task' => '2',
                'context' => {},
              },
              {
                'id' => event1.id.to_s,
                'timestamp' => timestamp.to_i,
                'user' => 'test',
                'action' => 'create',
                'object_type' => 'deployment',
                'object_name' => 'depl1',
                'task' => '1',
                'context' => {},
              },
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
            min_id = event2.id + 51
            max_id = min_id + 199
            expected_ids = *(min_id..max_id)
            expect(response_ids).to eq(expected_ids.reverse)
          end
        end

        context 'event' do
          let!(:event1) do
            FactoryBot.create(:models_event,
              timestamp: timestamp,
              user: 'test',
              action: 'create',
              object_type: 'deployment',
              object_name: 'depl1',
              task: '1',
            )
          end

          let!(:event2) do
            FactoryBot.create(:models_event,
              parent_id: event1.id,
              timestamp: timestamp,
              user: 'test',
              action: 'create',
              object_type: 'deployment',
              object_name: 'depl1',
              task: '2',
            )
          end

          it 'returns event' do
            basic_authorize 'admin', 'admin'

            get "/#{event2.id}"

            expect(JSON.parse(last_response.body)).to eq(
              'id' => event2.id.to_s,
              'parent_id' => event1.id.to_s,
              'timestamp' => timestamp.to_i,
              'user' => 'test',
              'action' => 'create',
              'object_type' => 'deployment',
              'object_name' => 'depl1',
              'task' => '2',
              'context' => {},
            )
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
            FactoryBot.create(:models_event, deployment: 'name')
            FactoryBot.create(:models_event, deployment: 'not the droid we are looking for')
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
            FactoryBot.create(:models_event, task: 4)
            FactoryBot.create(:models_event, task: 5)
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
            FactoryBot.create(:models_event, instance: 'job/4')
            FactoryBot.create(:models_event, instance: 'job/5')
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
            FactoryBot.create(:models_event, user: 'admin')
            FactoryBot.create(:models_event, user: 'user')
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
            FactoryBot.create(:models_event, action: 'delete')
            FactoryBot.create(:models_event, action: 'update')
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
            FactoryBot.create(:models_event, object_type: 'deployment')
            FactoryBot.create(:models_event, object_type: 'instance')
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
            FactoryBot.create(:models_event, object_name: 'fake_name')
            FactoryBot.create(:models_event, object_name: 'another_name')
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
            let!(:event1) { FactoryBot.create(:models_event, instance: 'job/4') }
            let!(:event2) { FactoryBot.create(:models_event, instance: 'job/5', task: 4, deployment: 'name') }
            let!(:event3) { FactoryBot.create(:models_event, task: 5) }
            let!(:event4) { FactoryBot.create(:models_event, deployment: 'not the droid we are looking for') }

            it 'returns the anded results' do
              get "?instance=job/5&task=4&deployment=name&before_id=#{event2.id + 1}"
              events = JSON.parse(last_response.body)
              expect(events.size).to eq(1)
              expect(events[0]['instance']).to eq('job/5')
              expect(events[0]['task']).to eq('4')
              expect(events[0]['deployment']).to eq('name')
            end
          end

          context 'when user, action, object_name and object_type are specified' do
            before do
              FactoryBot.create(:models_event, user: 'admin')
              FactoryBot.create(:models_event, user: 'admin', action: 'update', object_name: 'test', object_type: 'deployment')
              FactoryBot.create(:models_event, user: 'admin', action: 'update', object_name: 'test', object_type: 'deployment1')
              FactoryBot.create(:models_event, object_name: 'something')
              FactoryBot.create(:models_event, object_type: 'deployment')
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
              before_event = Models::Event.order(:timestamp).all[16]
              after_event = Models::Event.order(:timestamp).all[14]
              before_time = CGI.escape(before_event.timestamp.to_s)
              after_time = CGI.escape(after_event.timestamp.to_s)

              get "?before_time=#{before_time}&after_time=#{after_time}"
              events = JSON.parse(last_response.body)
              expect(events.size).to eq(1)
              expect(events.first['id']).to eq(Models::Event.order(:timestamp).all[15].id.to_s)
            end
          end

          context 'when after and before_id are specified' do
            before do
              make_events(20)
            end

            it 'returns the correct result' do
              before_id = Models::Event.order(:id).all[14].id
              after_time = CGI.escape(Models::Event.order(:timestamp).all[12].timestamp.to_s)
              get "?before_id=#{before_id}&after_time=#{after_time}"
              events = JSON.parse(last_response.body)
              expect(events.size).to eq(1)
              expect(events.first['id']).to eq((before_id - 1).to_s)
            end
          end
        end

        context 'when before is specified' do
          before do
            basic_authorize 'admin', 'admin'
          end

          it 'returns STATUS 400 if before has wrong format' do
            get '?before_time=Wrong'
            expect(last_response.status).to eq(400)
            expect(last_response.body).to eq("Invalid before parameter: 'Wrong' ")
          end

          it 'returns a list of events' do
            make_events(210)
            expect(Models::Event.count).to eq(210)

            before_event = Models::Event.order(:timestamp).all[201]
            before_time = CGI.escape(before_event.timestamp.to_s)
            get "?before_time=#{before_time}"
            events = JSON.parse(last_response.body)

            expect(events.size).to eq(200) # 200 limit
            response_ids = events.map { |e| e['id'].to_i }
            max_id = before_event.id - 1
            expected_ids = *((max_id - 199)..max_id) # exclusive
            expect(response_ids).to eq(expected_ids.reverse)
          end

          it 'supports date as Integer' do
            make_events(10)
            get "?before_time=#{Models::Event.order(:timestamp).all[1].timestamp.to_i}"
            events = JSON.parse(last_response.body)

            expect(events.size).to eq(1)
            expect(events.first['id']).to eq(Models::Event.order(:timestamp).all[0].id.to_s)
          end

          it 'supports date as specified in the event table' do
            make_events(10)
            before_time = CGI.escape(Models::Event.order(:timestamp).all[1].timestamp.utc.strftime('%a %b %d %H:%M:%S %Z %Y'))
            get "?before_time=#{before_time}"
            events = JSON.parse(last_response.body)

            expect(events.size).to eq(1)
            expect(events.first['id']).to eq(Models::Event.order(:timestamp).all[0].id.to_s)
          end
        end

        context 'when after is specified' do
          before do
            basic_authorize 'admin', 'admin'
          end

          it 'returns STATUS 400 if after has wrong format' do
            get '?after_time=Wrong'
            expect(last_response.status).to eq(400)
            expect(last_response.body).to eq("Invalid after parameter: 'Wrong' ")
          end

          it 'returns a list of events' do
            make_events(210)
            expect(Models::Event.count).to eq(210)

            after_event = Models::Event.order(:timestamp).all[9]
            after_time = CGI.escape(after_event.timestamp.to_s)
            get "?after_time=#{after_time}"
            events = JSON.parse(last_response.body)

            expect(events.size).to eq(200)
            response_ids = events.map { |e| e['id'].to_i }
            min_id = after_event.id + 1
            expected_ids = *(min_id..(min_id + 199))
            expect(response_ids).to eq(expected_ids.reverse)
          end

          it 'supports date as Integer' do
            make_events(10)
            get "?after_time=#{Models::Event.order(:timestamp).all[8].timestamp.to_i}"
            events = JSON.parse(last_response.body)

            expect(events.size).to eq(1)
            expect(events.first['id']).to eq(Models::Event.order(:timestamp).all[9].id.to_s)
          end

          it 'supports date as specified in the event table' do
            make_events(10)
            after_time = CGI.escape(Models::Event.order(:timestamp).all[8].timestamp.utc.strftime('%a %b %d %H:%M:%S %Z %Y'))
            get "?after_time=#{after_time}"
            events = JSON.parse(last_response.body)

            expect(events.size).to eq(1)
            expect(events.first['id']).to eq(Models::Event.order(:timestamp).all[9].id.to_s)
          end
        end

        context 'when before_id is specified' do
          before do
            basic_authorize 'admin', 'admin'
          end

          it 'returns a list of events' do
            make_events(250)

            before_event = Models::Event.order(:id).all[229]
            get "?before_id=#{before_event.id}"
            events = JSON.parse(last_response.body)

            expect(events.size).to eq(200)
            response_ids = events.map { |e| e['id'].to_i }
            max_id = before_event.id - 1
            min_id = max_id - 199
            expected_ids = *(min_id..max_id)
            expect(response_ids).to eq(expected_ids.reverse)
          end

          it 'returns correct number of events' do
            make_events(250)
            delete_after = Models::Event.order(:id).all[199]
            Models::Event.filter(Sequel.lit('id > ?', delete_after.id)).delete

            make_events(50)

            before_event = Models::Event.order(:id).all[219]
            get "?before_id=#{before_event.id}"
            body = JSON.parse(last_response.body)

            expect(body.size).to eq(200)
            response_ids = body.map { |e| e['id'].to_i }
            events = Models::Event.order(:id).all
            expected_ids = [*events[19..218].map(&:id)]
            expect(response_ids).to eq(expected_ids.reverse)
          end

          context 'when number of returned events is less than EVENT_LIMIT' do
            it 'returns empty list if before_id < minimal id' do
              make_events(10)
              Models::Event.filter(Sequel.lit('id <  ?', 5)).delete
              get '?before_id=4'
              body = JSON.parse(last_response.body)

              expect(last_response.status).to eq(200)
              expect(body.size).to eq(0)
            end

            it 'returns a list of events before_id' do
              make_events(10)
              before_event = Models::Event.order(:id).all[2]
              get "?before_id=#{before_event.id}"

              body = JSON.parse(last_response.body)
              response_ids = body.map { |e| e['id'] }

              expect(last_response.status).to eq(200)
              expect(body.size).to eq(2)
              expect(response_ids).to eq([before_event.id - 1, before_event.id - 2].map(&:to_s))
            end
          end
        end
      end

      describe 'post' do
        let(:action) { 'create' }
        let(:context) do
          { 'information' => 'blah blah' }
        end
        let(:payload) do
          {
            action: action,
            object_type: 'deployment',
            object_name: 'depl1',
            deployment: 'new_deployment',
            instance: 'new_instance',
            error: 'some error',
            context: context,
          }
        end

        def perform
          post '/',
               JSON.generate(payload),
               'CONTENT_TYPE' => 'application/json'
        end

        context 'authenticated access' do
          before { authorize 'admin', 'admin' }

          it 'stores event' do
            expect { perform }.not_to raise_exception
            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq('')
            event = Models::Event.first
            expect(event.parent_id).to eq(nil)
            expect(event.user).to eq('admin')
            expect(event.action).to eq('create')
            expect(event.object_type).to eq('deployment')
            expect(event.object_name).to eq('depl1')
            expect(event.task).to eq(nil)
            expect(event.instance).to eq('new_instance')
            expect(event.error).to eq('some error')
            expect(event.context).to eq('information' => 'blah blah')
          end

          context 'when timestamp is specified' do
            let(:timestamp) { '1479673560' }
            let(:payload) do
              {
                action: action,
                timestamp: timestamp,
                object_type: 'deployment',
                object_name: 'depl1',
                deployment: 'new_deployment',
                instance: 'new_instance',
                error: 'some error',
                context: context,
              }
            end
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
                'description' => 'Context must be a hash',
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
