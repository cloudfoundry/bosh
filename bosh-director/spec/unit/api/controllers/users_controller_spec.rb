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

      let(:app) { described_class }

      def login_as_admin
        basic_authorize 'admin', 'admin'
      end

      def login_as(username, password)
        basic_authorize username, password
      end

      it 'requires auth' do
        get '/'
        expect(last_response.status).to eq(401)
      end

      it 'sets the date header' do
        get '/'
        expect(last_response.headers['Date']).not_to be_nil
      end

      it "allows Basic HTTP Auth with admin/admin credentials for test purposes (even though user doesn't exist)" do
        basic_authorize 'admin', 'admin'
        get '/'
        expect(last_response.status).to eq(404)
      end

      describe 'API calls' do
        before(:each) { login_as_admin }

        describe 'users' do
          let (:username) { 'john' }
          let (:password) { '123' }
          let (:user_data) { {'username' => 'john', 'password' => '123'} }

          it 'creates a user' do
            expect(Models::User.all.size).to eq(0)

            post '/', Yajl::Encoder.encode(user_data), { 'CONTENT_TYPE' => 'application/json' }

            new_user = Models::User[:username => username]
            expect(new_user).not_to be_nil
            expect(BCrypt::Password.new(new_user.password)).to eq(password)
          end

          it "doesn't create a user with existing username" do
            post '/', Yajl::Encoder.encode(user_data), { 'CONTENT_TYPE' => 'application/json' }

            login_as(username, password)
            post '/', Yajl::Encoder.encode(user_data), { 'CONTENT_TYPE' => 'application/json' }

            expect(last_response.status).to eq(400)
            expect(Models::User.all.size).to eq(1)
          end

          it 'updates user password but not username' do
            post '/', Yajl::Encoder.encode(user_data), { 'CONTENT_TYPE' => 'application/json' }

            login_as(username, password)
            new_data = {'username' => username, 'password' => '456'}
            put "/#{username}", Yajl::Encoder.encode(new_data), { 'CONTENT_TYPE' => 'application/json' }

            expect(last_response.status).to eq(204)
            user = Models::User[:username => username]
            expect(BCrypt::Password.new(user.password)).to eq('456')

            login_as(username, '456')
            change_name = {'username' => 'john2', 'password' => password}
            put "/#{username}", Yajl::Encoder.encode(change_name), { 'CONTENT_TYPE' => 'application/json' }
            expect(last_response.status).to eq(400)
            expect(last_response.body).to eq(
              "{\"code\":20001,\"description\":\"The username is immutable\"}"
            )
          end

          it 'deletes user' do
            post '/', Yajl::Encoder.encode(user_data), { 'CONTENT_TYPE' => 'application/json' }

            login_as(username, password)
            delete "/#{username}"

            expect(last_response.status).to eq(204)

            user = Models::User[:username => username]
            expect(user).to be_nil
          end
        end
      end
    end
  end
end
