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
        @rack_app ||= Controller.new
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
        last_response.status.should == 404
      end

      describe 'API calls' do
        before(:each) { login_as_admin }

        describe 'listing tasks' do
          it 'has API call that returns a list of running tasks' do
            ['queued', 'processing', 'cancelling', 'done'].each do |state|
              (1..20).map { |i| Models::Task.make(
                  :type => :update_deployment,
                  :state => state,
                  :timestamp => Time.now.to_i - i) }
            end
            get '/tasks?state=processing'
            last_response.status.should == 200
            body = Yajl::Parser.parse(last_response.body)
            body.size.should == 20

            get '/tasks?state=processing,cancelling,queued'
            last_response.status.should == 200
            body = Yajl::Parser.parse(last_response.body)
            body.size.should == 60
          end

          it 'has API call that returns a list of recent tasks' do
            ['queued', 'processing'].each do |state|
              (1..20).map { |i| Models::Task.make(
                  :type => :update_deployment,
                  :state => state,
                  :timestamp => Time.now.to_i - i) }
            end
            get '/tasks?limit=20'
            last_response.status.should == 200
            body = Yajl::Parser.parse(last_response.body)
            body.size.should == 20
          end
        end

        describe 'polling task status' do
          it 'has API call that return task status' do
            post '/releases', spec_asset('tarball.tgz'), { 'CONTENT_TYPE' => 'application/x-compressed' }
            new_task_id = last_response.location.match(/\/tasks\/(\d+)/)[1]

            get "/tasks/#{new_task_id}"

            last_response.status.should == 200
            task_json = Yajl::Parser.parse(last_response.body)
            task_json['id'].should == 1
            task_json['state'].should == 'queued'
            task_json['description'].should == 'create release'

            task = Models::Task[new_task_id]
            task.state = 'processed'
            task.save

            get "/tasks/#{new_task_id}"
            last_response.status.should == 200
            task_json = Yajl::Parser.parse(last_response.body)
            task_json['id'].should == 1
            task_json['state'].should == 'processed'
            task_json['description'].should == 'create release'
          end

          it 'has API call that return task output and task output with ranges' do
            post '/releases', spec_asset('tarball.tgz'), { 'CONTENT_TYPE' => 'application/x-compressed' }

            new_task_id = last_response.location.match(/\/tasks\/(\d+)/)[1]

            output_file = File.new(File.join(temp_dir, 'debug'), 'w+')
            output_file.print('Test output')
            output_file.close

            task = Models::Task[new_task_id]
            task.output = temp_dir
            task.save

            get "/tasks/#{new_task_id}/output"
            last_response.status.should == 200
            last_response.body.should == 'Test output'
          end

          it 'has API call that return task output with ranges' do
            post '/releases', spec_asset('tarball.tgz'), { 'CONTENT_TYPE' => 'application/x-compressed' }
            new_task_id = last_response.location.match(/\/tasks\/(\d+)/)[1]

            output_file = File.new(File.join(temp_dir, 'debug'), 'w+')
            output_file.print('Test output')
            output_file.close

            task = Models::Task[new_task_id]
            task.output = temp_dir
            task.save

            # Range test
            get "/tasks/#{new_task_id}/output", {}, {'HTTP_RANGE' => 'bytes=0-3'}
            last_response.status.should == 206
            last_response.body.should == 'Test'
            last_response.headers['Content-Length'].should == '4'
            last_response.headers['Content-Range'].should == 'bytes 0-3/11'

            # Range test
            get "/tasks/#{new_task_id}/output", {}, {'HTTP_RANGE' => 'bytes=5-'}
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
              get "/tasks/#{task.id}/output?type=#{log_type}"
              last_response.status.should == 200
              last_response.body.should == "Test output #{log_type}"
            end

            # Backward compatibility: when log_type=soap return cpi log
            get "/tasks/#{task.id}/output?type=soap"
            last_response.status.should == 200
            last_response.body.should == 'Test output cpi'

            # Default output is debug
            get "/tasks/#{task.id}/output"
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
              get "/tasks/#{task.id}/output?type=#{log_type}"
              last_response.status.should == 200
              last_response.body.should == 'Test output soap'
            end
          end
        end
      end
    end
  end
end
