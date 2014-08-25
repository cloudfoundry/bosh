require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::TasksController do
      include Rack::Test::Methods

      let!(:temp_dir) { Dir.mktmpdir}

      before do
        blobstore_dir = File.join(temp_dir, 'blobstore')
        FileUtils.mkdir_p(blobstore_dir)

        test_config = Psych.load(spec_asset('test-director-config.yml'))
        test_config['dir'] = temp_dir
        test_config['blobstore'] = {
          'provider' => 'local',
          'options' => {'blobstore_path' => blobstore_dir}
        }
        test_config['snapshots']['enabled'] = true
        Config.configure(test_config)
        @director_app = App.new(Config.load_hash(test_config))
      end

      after do
        FileUtils.rm_rf(temp_dir)
      end

      def app
        @rack_app ||= described_class.new
      end

      def login_as_admin
        basic_authorize 'admin', 'admin'
      end

      def login_as(username, password)
        basic_authorize username, password
      end

      it 'requires auth' do
        get '/'
        last_response.status.should == 401
      end

      it 'sets the date header' do
        get '/'
        last_response.headers['Date'].should_not be_nil
      end

      it 'allows Basic HTTP Auth with admin/admin credentials for ' +
             "test purposes (even though user doesn't exist)" do
        basic_authorize 'admin', 'admin'
        get '/'
        last_response.status.should == 200
      end

      describe 'API calls' do
        before(:each) { login_as_admin }

        describe 'GET /' do
          context "verbose" do
            let(:concise_task_types) {
              %w[
                create_snapshot
                delete_deployment
                delete_release
                delete_snapshot
                delete_stemcell
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
                last_response.status.should == 200
                body = Yajl::Parser.parse(last_response.body)
                actual_ids = body.map { |attributes| attributes["id"] }
                actual_tasks = Models::Task.filter(id: actual_ids)

                actual_tasks.should =~ all_tasks.select do |task|
                  concise_task_types.include?(task.type)
                end
              end
            end

            context "when verbose is set to 2" do
              it "does not filter tasks by type" do
                get "/?verbose=2"
                last_response.status.should == 200
                body = Yajl::Parser.parse(last_response.body)
                actual_ids = body.map { |attributes| attributes["id"] }
                actual_tasks = Models::Task.filter(id: actual_ids)
                actual_tasks.should =~ all_tasks
              end
            end

            context "when verbose is not set" do
              it "filters all but the expected task types" do
                get "/"
                last_response.status.should == 200
                body = Yajl::Parser.parse(last_response.body)
                actual_ids = body.map { |attributes| attributes["id"] }
                actual_tasks = Models::Task.filter(id: actual_ids)

                actual_tasks.should =~ all_tasks.select do |task|
                  concise_task_types.include?(task.type)
                end
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
              last_response.status.should == 200
              body = Yajl::Parser.parse(last_response.body)
              actual_ids = body.map { |attributes| attributes["id"] }
              actual_tasks = Models::Task.filter(id: actual_ids).to_a
              actual_tasks.map(&:id).should == [expected_task.id]
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
                last_response.status.should == 200
                body = Yajl::Parser.parse(last_response.body)
                body.size.should == 1
              end
            end

            context "when the limit is greater than 1" do
              it "limits the tasks returned to the limit provided" do
                get '/?limit=10'
                last_response.status.should == 200
                body = Yajl::Parser.parse(last_response.body)
                body.size.should == 10
              end
            end
          end
        end

        describe 'polling task status' do
          it 'has API call that return task status' do
            task = Models::Task.make(state: 'queued', description: 'fake-description')

            get "/#{task.id}"
            last_response.status.should == 200
            task_json = Yajl::Parser.parse(last_response.body)
            task_json['id'].should == task.id
            task_json['state'].should == 'queued'
            task_json['description'].should == 'fake-description'

            task.state = 'processed'
            task.save

            get "/#{task.id}"
            last_response.status.should == 200
            task_json = Yajl::Parser.parse(last_response.body)
            task_json['id'].should == 1
            task_json['state'].should == 'processed'
            task_json['description'].should == 'fake-description'
          end

          it 'has API call that return task output and task output with ranges' do
            output_file = File.new(File.join(temp_dir, 'debug'), 'w+')
            output_file.print('Test output')
            output_file.close

            task = Models::Task.make(output: temp_dir)

            get "/#{task.id}/output"
            last_response.status.should == 200
            last_response.body.should == 'Test output'
          end

          it 'has API call that return task output with ranges' do
            output_file = File.new(File.join(temp_dir, 'debug'), 'w+')
            output_file.print('Test output')
            output_file.close

            task = Models::Task.make(output: temp_dir)

            # Range test
            get "/#{task.id}/output", {}, {'HTTP_RANGE' => 'bytes=0-3'}
            last_response.status.should == 206
            last_response.body.should == 'Test'
            last_response.headers['Content-Length'].should == '4'
            last_response.headers['Content-Range'].should == 'bytes 0-3/11'

            # Range test
            get "/#{task.id}/output", {}, {'HTTP_RANGE' => 'bytes=5-'}
            last_response.status.should == 206
            last_response.body.should == 'output'
            last_response.headers['Content-Length'].should == '6'
            last_response.headers['Content-Range'].should == 'bytes 5-10/11'
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
              last_response.status.should == 200
              last_response.body.should == "Test output #{log_type}"
            end

            # Backward compatibility: when log_type=soap return cpi log
            get "/#{task.id}/output?type=soap"
            last_response.status.should == 200
            last_response.body.should == 'Test output cpi'

            # Default output is debug
            get "/#{task.id}/output"
            last_response.status.should == 200
            last_response.body.should == 'Test output debug'
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
              last_response.status.should == 200
              last_response.body.should == 'Test output soap'
            end
          end
        end
      end
    end
  end
end
