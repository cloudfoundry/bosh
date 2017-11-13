require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::TasksController do
      include Rack::Test::Methods

      subject(:app) { linted_rack_app(described_class.new(config)) }

      let(:temp_dir) { Dir.mktmpdir }

      let(:deployment_name_1) { 'deployment1' }
      let(:deployment_name_2) { 'deployment2' }
      let(:deployment_name_3) { 'deployment3' }
      let(:team_rocket) { Models::Team.make(name: 'team-rocket') }
      let(:dev) { Models::Team.make(name: 'dev') }

      let(:config) do
        config = Config.load_hash(SpecHelper.spec_get_director_config)
        identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
        allow(config).to receive(:identity_provider).and_return(identity_provider)
        config
      end

      after { FileUtils.rm_rf(temp_dir) }

      it 'requires auth' do
        get '/'
        expect(last_response.status).to eq(401)
      end

      it 'sets the date header' do
        get '/'
        expect(last_response.headers['Date']).not_to be_nil
      end

      it 'allows Basic HTTP Auth with admin/admin credentials for ' +
          "test purposes (even though user doesn't exist)" do
        basic_authorize 'admin', 'admin'
        get '/'
        expect(last_response.status).to eq(200)
      end

      it "allows Basic HTTP Auth with admin/admin credentials for test purposes (even though user doesn't exist)" do
        basic_authorize 'reader', 'reader'
        get '/'
        expect(last_response.status).to eq(200)
      end

      it "allows Basic HTTP Auth with team admin credentials for test purposes (even though user doesn't exist)" do
        basic_authorize 'dev-team-member', 'dev-team-member'
        get '/'
        expect(last_response.status).to eq(200)
      end

      describe 'API calls' do
        describe 'GET /' do

          let(:parsed_body) { JSON.parse(last_response.body) }

          context 'when user has admin access' do
            before(:each) { basic_authorize 'admin', 'admin' }

            context 'collection of tasks associated with different deployments' do
              before do
                make_task_with_team(type: 'attach_disk', deployment_name: deployment_name_1, teams: [team_rocket, dev])
                make_task_with_team(type: 'delete_deployment', deployment_name: deployment_name_1, teams: [team_rocket, dev])
                make_task_with_team(type: 'run_errand', deployment_name: deployment_name_2, teams: [team_rocket])
                make_task_with_team(type: 'snapshot_deployment', deployment_name: deployment_name_1, teams: [team_rocket, dev])
                make_task_with_team(type: 'update_deployment', deployment_name: deployment_name_2, teams: [team_rocket])
                Models::Task.make(type: 'create_snapshot')
                Models::Task.make(type: 'delete_release')
                Models::Task.make(type: 'delete_snapshot')
                Models::Task.make(type: 'delete_stemcell')
                Models::Task.make(type: 'update_release')
                Models::Task.make(type: 'update_stemcell')
              end

              context 'when deployment name 1 is used as a query parameter' do
                it 'filters tasks with that deployment name' do
                  get "/?deployment=#{deployment_name_1}"
                  expect(last_response.status).to eq(200)
                  deployment_names = parsed_body.map { |attributes| attributes['deployment'] }
                  expect(deployment_names.uniq).to match([deployment_name_1])
                end
              end
            end

            context 'when a state is passed' do
              it 'filters all but tasks with that state' do
                expected_task = Models::Task.make(
                  type: :update_deployment, state: :queued
                )
                filtered_task = Models::Task.make(
                  type: :update_deployment, state: :processing
                )
                get '/?state=queued'
                expect(last_response.status).to eq(200)
                actual_ids = parsed_body.map { |attributes| attributes['id'] }
                actual_tasks = Models::Task.filter(id: actual_ids).to_a
                expect(actual_tasks.map(&:id)).to eq([expected_task.id])
              end
            end

            context 'when a limit is passed' do
              before do
                (1..20).map { |i|
                  Models::Task.make(
                    :type => :update_deployment,
                    :state => :queued,
                  )
                }
              end

              context 'when the limit is less than 1' do
                it 'limits the tasks returned to 1' do
                  get '/?limit=0'
                  expect(last_response.status).to eq(200)
                  expect(parsed_body.size).to eq(1)
                end
              end

              context 'when the limit is greater than 1' do
                it 'limits the tasks returned to the limit provided' do
                  get '/?limit=10'
                  expect(last_response.status).to eq(200)
                  expect(parsed_body.size).to eq(10)
                end
              end
            end

            context 'verbose' do
              let(:concise_task_types) {
                %w[
                  attach_disk
                  create_snapshot
                  delete_deployment
                  delete_release
                  delete_snapshot
                  delete_stemcell
                  run_errand
                  snapshot_deployment
                  update_deployment
                  update_release
                  update_stemcell
                ]
              }

              let!(:all_tasks) do # one task of every type
                (
                Bosh::Director::Jobs.constants.inject([]) { |memo, const|
                  klass = Bosh::Director::Jobs.const_get(const)
                  if klass.ancestors.include?(Bosh::Director::Jobs::BaseJob)
                    memo << klass
                  end
                  memo
                } - [Bosh::Director::Jobs::BaseJob]
                ).map(&:job_type).map { |job_type|
                  Models::Task.make(type: job_type)
                }
              end

              context 'when verbose is set to 1' do
                it 'filters all but the expected task types' do
                  get '/?verbose=1'
                  expect(last_response.status).to eq(200)
                  actual_ids = parsed_body.map { |attributes| attributes['id'] }
                  actual_tasks = Models::Task.filter(id: actual_ids).order(:id)
                  expect(actual_tasks).to match(all_tasks.select { |task| concise_task_types.include?(task.type) })
                end
              end

              context 'when verbose is set to 2' do
                it 'does not filter tasks by type' do
                  get '/?verbose=2'
                  expect(last_response.status).to eq(200)
                  actual_ids = parsed_body.map { |attributes| attributes['id'] }
                  actual_tasks = Models::Task.filter(id: actual_ids).order(:id)
                  expect(actual_tasks).to match(all_tasks)
                end
              end

              context 'when verbose is not set' do
                it 'filters all but the expected task types' do
                  get '/'
                  expect(last_response.status).to eq(200)
                  actual_ids = parsed_body.map { |attributes| attributes['id'] }
                  actual_tasks = Models::Task.filter(id: actual_ids).order(:id)

                  expect(actual_tasks).to match(all_tasks.select { |task| concise_task_types.include?(task.type) })
                end
              end
            end
          end

          context 'when user has readonly access' do
            before do
              team_a = Models::Team.make(name: 'team_a')
              (1..20).map { |i|
                make_task_with_team(
                  :type => :update_deployment,
                  :state => :queued,
                  :deployment_name => "deployment_dev#{i%2}",
                  :teams => i%2 == 0 ? [team_a, team_rocket] : [team_rocket, dev]
                )
              }

              basic_authorize 'dev-team-member', 'dev-team-member'
            end

            it 'provides list of tasks of deployments you have access to' do
              get '/'
              expect(last_response.status).to eq(200)
              expect(parsed_body.size).to eq(10)
            end
          end

          context 'when user has team admin permissions' do
            before do
              Models::Task.make(type: 'update_stemcell', deployment_name: nil, teams: nil)
              make_task_with_team(type: 'attach_disk', deployment_name: deployment_name_1, teams: [team_rocket, dev])
            end

            before do
              basic_authorize 'dev-team-member', 'dev-team-member'
            end

            context 'when user does not have access to all tasks' do
              before do
                10.times do
                  make_task_with_team(type: 'attach_disk', deployment_name: deployment_name_2, teams: [team_rocket, dev])
                  make_task_with_team(type: 'attach_disk', deployment_name: deployment_name_3, teams: [team_rocket])
                end
              end
              it 'shows the limit amount of tasks' do
                get '/?limit=10'
                expect(last_response.status).to eq(200)
                expect(parsed_body.size).to eq(10)
                expect(parsed_body.all?{ |e| e['deployment'] != 'deployment3' }).to eq(true)
              end

              it 'shows the limit amount of tasks and filter by deployment' do
                get "/?deployment=#{deployment_name_2}&limit=11"
                expect(last_response.status).to eq(200)
                expect(parsed_body.size).to eq(10)
                expect(parsed_body.all?{ |e| e['deployment'] == 'deployment2' }).to eq(true)
              end
            end

            context 'if user has access to deployment' do
              it 'filters tasks with that deployment name' do
                get "/?deployment=#{deployment_name_1}"
                expect(last_response.status).to eq(200)
                expect(parsed_body.size).to eq(1)
              end
            end

            context 'when task has empty deployment_name' do
              it 'does not show up in the response' do
                get '/'
                expect(last_response.status).to eq(200)
                expect(parsed_body.size).to eq(1)
              end
            end

            context 'when task has a deployment associated with it and the deployment has already been deleted' do
              let(:prod) { Models::Team.make(name: 'prod')}
              it 'should show up in the response' do
                make_task_with_team(type: 'update_deployment', deployment_name: 'deleted_deployment', teams: [team_rocket, prod])
                make_task_with_team(type: 'delete_deployment', deployment_name: 'deleted_deployment', teams: [team_rocket, dev])
                get '/'
                expect(last_response.status).to eq(200)

                expect(parsed_body.size).to eq(2)
              end
            end
          end

          context 'when context id is passed' do
            before do
              Models::Task.make(type: 'create_snapshot', context_id: 'example-context-id')
              Models::Task.make(type: 'delete_release', context_id: 'example-context-id')
              Models::Task.make(type: 'delete_snapshot')
              Models::Task.make(type: 'delete_stemcell', context_id: 'some-other-context-id')
            end

            before do
              basic_authorize 'admin', 'admin'
            end

            it 'only returns tasks with the same context' do
              context_id = 'example-context-id'
              get "/?context_id=#{context_id}"
              expect(last_response.status).to eq(200)
              expect(parsed_body.size).to eq(2)
              expect(parsed_body.all?{ |e| e['context_id'] == context_id }).to eq(true)
            end
          end
        end

        describe 'get task by id' do
          let(:task) { Models::Task.make(state: 'queued', description: 'fake-description') }

          context 'user has readonly access' do
            before(:each) { basic_authorize 'reader', 'reader' }

            it 'provides access if accessing task' do
              get "/#{task.id}"
              expect(last_response.status).to eq(200)
            end
          end

          context 'user has admin access' do
            before(:each) { basic_authorize 'admin', 'admin' }

            it 'has API call that return task status' do
              task = Models::Task.make(state: 'queued', description: 'fake-description')

              get "/#{task.id}"
              expect(last_response.status).to eq(200)
              task_json = JSON.parse(last_response.body)
              expect(task_json['id']).to eq(task.id)
              expect(task_json['state']).to eq('queued')
              expect(task_json['description']).to eq('fake-description')

              task.state = 'processed'
              task.save

              get "/#{task.id}"
              expect(last_response.status).to eq(200)
              task_json = JSON.parse(last_response.body)
              expect(task_json['id']).to eq(1)
              expect(task_json['state']).to eq('processed')
              expect(task_json['description']).to eq('fake-description')
            end

            context 'when the task has a context id' do
              it 'has API call that returns task context id' do
                context_id = 'example-context-id'
                task = Models::Task.make(context_id: context_id)

                get "/#{task.id}"
                expect(last_response.status).to eq(200)
                task_json = JSON.parse(last_response.body)
                expect(task_json['context_id']).to eq context_id
              end
            end

            context 'user has access to task' do
              let(:task) { make_task_with_team(state: 'queued', deployment_name: deployment_name_1, teams: [team_rocket, dev]) }

              it 'returns task' do
                get "/#{task.id}"
                expect(last_response.status).to eq(200)
              end
            end

            context 'user does not have access to task' do
              let(:task) { make_task_with_team(state: 'queued', deployment_name: deployment_name_1, teams: [team_rocket]) }

              it 'returns task' do
                get "/#{task.id}"
                expect(last_response.status).to eq(200)
              end
            end
          end

          context 'user has team admin access' do
            context "user doesn't have access to task" do
              before do
                basic_authorize 'dev-team-member', 'dev-team-member'
              end

              let(:task) { make_task_with_team(state: 'queued', deployment_name: deployment_name_1, :teams =>[team_rocket]) }
              it 'returns 401' do
                get "/#{task.id}"
                expect(last_response.status).to eq(401)
                expect(last_response.body).to include('bosh.teams.team-rocket.admin')
              end
            end

            context 'user has access to task' do
              before do
                basic_authorize 'dev-team-member', 'dev-team-member'
              end

              let(:task) { make_task_with_team(state: 'queued', deployment_name: deployment_name_1, :teams => [team_rocket, dev]) }
              it 'returns 200' do
                get "/#{task.id}"
                expect(last_response.status).to eq(200)
              end
            end
          end
        end

        describe 'get task output' do

          context 'user has admin access' do
            before(:each) { basic_authorize 'admin', 'admin' }

            let(:task) { Models::Task.make(output: temp_dir) }
            it 'has API call that return task output and task output with ranges' do
              output_file = File.new(File.join(temp_dir, 'debug'), 'w+')
              output_file.print('Test output')
              output_file.close

              task = Models::Task.make(output: temp_dir)

              get "/#{task.id}/output"
              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq('Test output')
            end

            it 'has API call that return task output with ranges' do
              output_file = File.new(File.join(temp_dir, 'debug'), 'w+')
              output_file.print('Test output')
              output_file.close

              # Range test
              get "/#{task.id}/output", {}, {'HTTP_RANGE' => 'bytes=0-3'}
              expect(last_response.status).to eq(206)
              expect(last_response.body).to eq('Test')
              expect(last_response.headers['Content-Length']).to eq('4')
              expect(last_response.headers['Content-Range']).to eq('bytes 0-3/11')

              # Range test
              get "/#{task.id}/output", {}, {'HTTP_RANGE' => 'bytes=5-'}
              expect(last_response.status).to eq(206)
              expect(last_response.body).to eq('output')
              expect(last_response.headers['Content-Length']).to eq('6')
              expect(last_response.headers['Content-Range']).to eq('bytes 5-10/11')
            end

            it 'has API call that return task output from db with ranges' do
              task1 = Models::Task.make(state: 'queued', description: 'fake-description', event_output: "Test output", output: "something")

              # Range test
              get "/#{task1.id}/output?type=event", {}, {'HTTP_RANGE' => 'bytes=0-3'}
              expect(last_response.status).to eq(206)
              expect(last_response.body).to eq('Test')
              expect(last_response.headers['Content-Length']).to eq('4')
              expect(last_response.headers['Content-Range']).to eq('bytes 0-3/11')

              # Range test
              get "/#{task1.id}/output?type=event", {}, {'HTTP_RANGE' => 'bytes=5-'}
              expect(last_response.status).to eq(206)
              expect(last_response.body).to eq('output')
              expect(last_response.headers['Content-Length']).to eq('6')
              expect(last_response.headers['Content-Range']).to eq('bytes 5-10/11')
            end

            it 'supports returning different types of output (debug, cpi, event, result) from file' do
              %w(debug event cpi result).each do |log_type|
                output_file = File.new(File.join(temp_dir, log_type), 'w+')
                output_file.print("Test output #{log_type}")
                output_file.close
              end

              task = Models::Task.new
              task.state = 'done'
              task.type = :update_deployment
              task.timestamp = Time.now
              task.description = 'description'
              task.output = temp_dir
              task.save

              %w(debug event cpi result).each do |log_type|
                get "/#{task.id}/output?type=#{log_type}"
                expect(last_response.status).to eq(200)
                expect(last_response.body).to eq("Test output #{log_type}")
              end

              # Default output is debug
              get "/#{task.id}/output"
              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq('Test output debug')
            end

            it 'supports returning different types of output (event, result) from db' do
              task = Models::Task.new
              task.state = 'done'
              task.type = :update_deployment
              task.timestamp = Time.now
              task.description = 'description'
              task.output = temp_dir
              task.result_output = 'Test output result from db'
              task.event_output = 'Test output event from db'
              task.save

              %w(event result).each do |log_type|
                get "/#{task.id}/output?type=#{log_type}"
                expect(last_response.status).to eq(200)
                expect(last_response.body).to eq("Test output #{log_type} from db")
              end
            end

            context "task's deployment doesn't exist" do
              let(:task) { Models::Task.make(output: temp_dir, deployment_name: 'deleted') }
              it 'gets task output' do
                get "/#{task.id}/output"
                expect(last_response.status).to eq(204)
              end
            end
            context 'task has no deployment' do
              it 'gets task output' do
                get "/#{task.id}/output"
                expect(last_response.status).to eq(204)
              end
            end
          end

          context 'user has readonly access' do

            before(:each) { basic_authorize 'reader', 'reader' }

            let(:task) { Models::Task.make(state: 'queued', description: 'fake-description', event_output: "Test output") }

            it 'returns 401 for empty output type' do
              get "/#{task.id}/output"
              expect(last_response.status).to eq(401)
            end

            it 'returns 401 for debug output type' do
              get "/#{task.id}/output?type=debug"
              expect(last_response.status).to eq(401)
            end

            it 'returns 401 for cpi output type' do
              get "/#{task.id}/output?type=cpi"
              expect(last_response.status).to eq(401)
            end

            it 'provides access for event output type' do
              get "/#{task.id}/output?type=event"
              expect(last_response.status).to eq(204)
            end

            it 'provides access for result output type' do
              get "/#{task.id}/output?type=result"
              expect(last_response.status).to eq(204)
            end
          end

          context 'user has team admin access' do
            let(:task_1) do
              make_task_with_team(
                type: :update_deployment,
                state: :queued,
                deployment_name: deployment_name_1,
                teams: [team_rocket, dev],
              )
            end
            let(:task_2) do
              make_task_with_team(
                type: :update_deployment,
                state: :queued,
                deployment_name: deployment_name_2,
                teams: [team_rocket],
              )
            end
            let(:task_deleted) do
              Models::Task.make(type: :update_deployment, state: :queued, deployment_name: 'deleted',)
            end

            let(:task_no_deployment) { Models::Task.make(type: :update_deployment, state: :queued) }

            before(:each) do
              Models::Deployment.create_with_teams(:name => deployment_name_1,
                :teams => [team_rocket, dev]
              )
              Models::Deployment.create_with_teams(:name => deployment_name_2,
                :teams => [team_rocket]
              )
              basic_authorize 'dev-team-member', 'dev-team-member'
            end

            context "user has access to task's deployment" do
              it 'has access to debug output type' do
                get "/#{task_1.id}/output?type=debug"
                expect(last_response.status).to eq(204)
              end
              it 'has access to cpi output type' do
                get "/#{task_1.id}/output?type=cpi"
                expect(last_response.status).to eq(204)
              end
              it 'has access to event output type' do
                get "/#{task_1.id}/output?type=event"
                expect(last_response.status).to eq(204)
              end
              it 'has access to result output type' do
                get "/#{task_1.id}/output?type=result"
                expect(last_response.status).to eq(204)
              end
              it 'has access to no type output type' do
                get "/#{task_1.id}/output"
                expect(last_response.status).to eq(204)
              end
            end
            context "user doesn't have access to task's deployment" do
              it 'returns 401 for every task type' do
                ['debug', 'cpi', 'event', 'result', ''].each do |type|
                  get "/#{task_2.id}/output?type=#{type}"
                  expect(last_response.status).to eq(401)
                end
              end
            end
            context 'if deployment got deleted' do
              it 'returns 401 for every task type' do
                ['debug', 'cpi', 'event', 'result', ''].each do |type|
                  get "/#{task_deleted.id}/output?type=#{type}"
                  expect(last_response.status).to eq(401)
                end
              end
            end
            context 'if task has no deployment' do
              it 'returns 401 for every task type' do
                ['debug', 'cpi', 'event', 'result', ''].each do |type|
                  get "/#{task_no_deployment.id}/output?type=#{type}"
                  expect(last_response.status).to eq(401)
                end
              end
            end
          end
        end
      end
    end
  end
end
