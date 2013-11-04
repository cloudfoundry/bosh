require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::UsersController do
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

      it "allows Basic HTTP Auth with admin/admin credentials for test purposes (even though user doesn't exist)" do
        basic_authorize 'admin', 'admin'
        get '/'
        last_response.status.should == 404
      end

      describe 'API calls' do
        before(:each) { login_as_admin }

        describe 'users' do
          let (:username) { 'john' }
          let (:password) { '123' }
          let (:user_data) { {'username' => 'john', 'password' => '123'} }

          it 'creates a user' do
            Models::User.all.size.should == 0

            post '/users', Yajl::Encoder.encode(user_data), { 'CONTENT_TYPE' => 'application/json' }

            new_user = Models::User[:username => username]
            new_user.should_not be_nil
            BCrypt::Password.new(new_user.password).should == password
          end

          it "doesn't create a user with exising username" do
            post '/users', Yajl::Encoder.encode(user_data), { 'CONTENT_TYPE' => 'application/json' }

            login_as(username, password)
            post '/users', Yajl::Encoder.encode(user_data), { 'CONTENT_TYPE' => 'application/json' }

            last_response.status.should == 400
            Models::User.all.size.should == 1
          end

          it 'updates user password but not username' do
            post '/users', Yajl::Encoder.encode(user_data), { 'CONTENT_TYPE' => 'application/json' }

            login_as(username, password)
            new_data = {'username' => username, 'password' => '456'}
            put "/users/#{username}", Yajl::Encoder.encode(new_data), { 'CONTENT_TYPE' => 'application/json' }

            last_response.status.should == 204
            user = Models::User[:username => username]
            BCrypt::Password.new(user.password).should == '456'

            login_as(username, '456')
            change_name = {'username' => 'john2', 'password' => password}
            put "/users/#{username}", Yajl::Encoder.encode(change_name), { 'CONTENT_TYPE' => 'application/json' }
            last_response.status.should == 400
            last_response.body.should ==
              "{\"code\":20001,\"description\":\"The username is immutable\"}"
          end

          it 'deletes user' do
            post '/users', Yajl::Encoder.encode(user_data), { 'CONTENT_TYPE' => 'application/json' }

            login_as(username, password)
            delete "/users/#{username}"

            last_response.status.should == 204

            user = Models::User[:username => username]
            user.should be_nil
          end
        end
      end
    end
  end
end
