require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::TasksController do
      include Rack::Test::Methods

      subject(:app) { described_class.new(config) }
      let(:temp_dir) { Dir.mktmpdir}
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

      let(:config) { Config.load_hash(test_config) }

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

      describe 'API calls' do
        before(:each) { basic_authorize 'admin', 'admin' }

        describe 'GET /' do
          context "verbose" do
            let(:concise_task_types) {
              %w[
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

            context "when verbose is set to 1" do
              it "filters all but the expected task types" do
                get "/?verbose=1"
                expect(last_response.status).to eq(200)
                body = Yajl::Parser.parse(last_response.body)
                actual_ids = body.map { |attributes| attributes["id"] }
                actual_tasks = Models::Task.filter(id: actual_ids)

                expect(actual_tasks).to match(all_tasks.select { |task| concise_task_types.include?(task.type) })
              end
            end

            context "when verbose is set to 2" do
              it "does not filter tasks by type" do
                get "/?verbose=2"
                expect(last_response.status).to eq(200)
                body = Yajl::Parser.parse(last_response.body)
                actual_ids = body.map { |attributes| attributes["id"] }
                actual_tasks = Models::Task.filter(id: actual_ids)
                expect(actual_tasks).to match(all_tasks)
              end
            end

            context "when verbose is not set" do
              it "filters all but the expected task types" do
                get "/"
                expect(last_response.status).to eq(200)
                body = Yajl::Parser.parse(last_response.body)
                actual_ids = body.map { |attributes| attributes["id"] }
                actual_tasks = Models::Task.filter(id: actual_ids)

                expect(actual_tasks).to match(all_tasks.select { |task| concise_task_types.include?(task.type) })
              end
            end
          end

          context "when a state is passed" do
            it "filters all but tasks with that state" do
              expected_task = Models::Task.make(
                type: :update_deployment, state: :queued
              )
              filtered_task = Models::Task.make(
                type: :update_deployment, state: :processing
              )
              get '/?state=queued'
              expect(last_response.status).to eq(200)
              body = Yajl::Parser.parse(last_response.body)
              actual_ids = body.map { |attributes| attributes["id"] }
              actual_tasks = Models::Task.filter(id: actual_ids).to_a
              expect(actual_tasks.map(&:id)).to eq([expected_task.id])
            end
          end

          context "when a limit is passed" do
            before do
              (1..20).map { |i|
                Models::Task.make(
                  :type => :update_deployment,
                  :state => :queued,
                )
              }
            end

            context "when the limit is less than 1" do
              it "limits the tasks returned to 1" do
                get '/?limit=0'
                expect(last_response.status).to eq(200)
                body = Yajl::Parser.parse(last_response.body)
                expect(body.size).to eq(1)
              end
            end

            context "when the limit is greater than 1" do
              it "limits the tasks returned to the limit provided" do
                get '/?limit=10'
                expect(last_response.status).to eq(200)
                body = Yajl::Parser.parse(last_response.body)
                expect(body.size).to eq(10)
              end
            end
          end
        end

        describe 'polling task status' do
          it 'has API call that return task status' do
            task = Models::Task.make(state: 'queued', description: 'fake-description')

            get "/#{task.id}"
            expect(last_response.status).to eq(200)
            task_json = Yajl::Parser.parse(last_response.body)
            expect(task_json['id']).to eq(task.id)
            expect(task_json['state']).to eq('queued')
            expect(task_json['description']).to eq('fake-description')

            task.state = 'processed'
            task.save

            get "/#{task.id}"
            expect(last_response.status).to eq(200)
            task_json = Yajl::Parser.parse(last_response.body)
            expect(task_json['id']).to eq(1)
            expect(task_json['state']).to eq('processed')
            expect(task_json['description']).to eq('fake-description')
          end

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

            task = Models::Task.make(output: temp_dir)

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

          it 'supports returning different types of output (debug, cpi, event)' do
            %w(debug event cpi).each do |log_type|
              output_file = File.new(File.join(temp_dir, log_type), 'w+')
              output_file.print("Test output #{log_type}")
              output_file.close
            end

            task = Models::Task.new
            task.state = 'done'
            task.type = :update_deployment
            task.timestamp = Time.now.to_i
            task.description = 'description'
            task.output = temp_dir
            task.save

            %w(debug event cpi).each do |log_type|
              get "/#{task.id}/output?type=#{log_type}"
              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq("Test output #{log_type}")
            end

            # Backward compatibility: when log_type=soap return cpi log
            get "/#{task.id}/output?type=soap"
            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq('Test output cpi')

            # Default output is debug
            get "/#{task.id}/output"
            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq('Test output debug')
          end

          it 'supports returning old soap logs when type = (cpi || soap)' do
            output_file = File.new(File.join(temp_dir, 'soap'), 'w+')
            output_file.print('Test output soap')
            output_file.close

            task = Models::Task.new
            task.state = 'done'
            task.type = :update_deployment
            task.timestamp = Time.now.to_i
            task.description = 'description'
            task.output = temp_dir
            task.save

            %w(soap cpi).each do |log_type|
              get "/#{task.id}/output?type=#{log_type}"
              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq('Test output soap')
            end
          end
        end
      end

      describe 'scope' do
        before(:each) { basic_authorize 'admin', 'admin' }
        let(:identity_provider) { Support::TestIdentityProvider.new }
        let(:config) do
          config = Config.load_hash(test_config)
          allow(config).to receive(:identity_provider).and_return(identity_provider)
          config
        end

        it 'accepts read scope for routes allowing read access' do
          get '/'
          expect(identity_provider.scope).to eq(:read)

          get '/task-id'
          expect(identity_provider.scope).to eq(:read)

          get '/task-id/output?type=event'
          expect(identity_provider.scope).to eq(:read)

          get '/task-id/output?type=debug'
          expect(identity_provider.scope).to eq(:write)

          get '/task-id/output?type=cpi'
          expect(identity_provider.scope).to eq(:write)
        end
      end
    end
  end
end
