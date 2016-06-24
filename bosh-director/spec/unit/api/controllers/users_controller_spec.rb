require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::UsersController do
      include Rack::Test::Methods

      subject(:app) { described_class.new(config) }
      let(:config) { Config.load_hash(test_config) }

      let(:test_config) { SpecHelper.spec_get_director_config }

      context 'when user management via API is supported' do
        before { test_config.delete('user_management') }

        describe 'API calls' do
          before(:each) { basic_authorize 'admin', 'admin' }

          describe 'users' do
            let (:username) { 'john' }
            let (:password) { '123' }
            let (:user_data) { {'username' => 'john', 'password' => '123'} }

            it 'creates a user' do
              expect(Models::User.all.size).to eq(0)

              post '/', JSON.generate(user_data), {'CONTENT_TYPE' => 'application/json'}

              new_user = Models::User[:username => username]
              expect(new_user).not_to be_nil
              expect(BCrypt::Password.new(new_user.password)).to eq(password)
            end

            it "doesn't create a user with existing username" do
              post '/', JSON.generate(user_data), {'CONTENT_TYPE' => 'application/json'}

              basic_authorize(username, password)
              post '/', JSON.generate(user_data), {'CONTENT_TYPE' => 'application/json'}

              expect(last_response.status).to eq(400)
              expect(Models::User.all.size).to eq(1)
            end

            it 'updates user password but not username' do
              post '/', JSON.generate(user_data), {'CONTENT_TYPE' => 'application/json'}

              basic_authorize(username, password)
              new_data = {'username' => username, 'password' => '456'}
              put "/#{username}", JSON.generate(new_data), {'CONTENT_TYPE' => 'application/json'}

              expect(last_response.status).to eq(204)
              user = Models::User[:username => username]
              expect(BCrypt::Password.new(user.password)).to eq('456')

              basic_authorize(username, '456')
              change_name = {'username' => 'john2', 'password' => password}
              put "/#{username}", JSON.generate(change_name), {'CONTENT_TYPE' => 'application/json'}
              expect(last_response.status).to eq(400)
              expect(last_response.body).to eq(
                  "{\"code\":20001,\"description\":\"The username is immutable\"}"
                )
            end

            it 'deletes user' do
              post '/', JSON.generate(user_data), {'CONTENT_TYPE' => 'application/json'}

              basic_authorize(username, password)
              delete "/#{username}"

              expect(last_response.status).to eq(204)

              user = Models::User[:username => username]
              expect(user).to be_nil
            end
          end
        end
      end

      context 'when user management via API is not supported' do
        before(:each) { basic_authorize 'admin', 'admin' }

        it 'fails to create user' do
          post '/', '', {'CONTENT_TYPE' => 'application/json'}
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq(
              "{\"code\":20004,\"description\":\"User management is not supported via API\"}"
            )
        end

        it 'fails to update user' do
          put '/fake-user', '', {'CONTENT_TYPE' => 'application/json'}
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq(
              "{\"code\":20004,\"description\":\"User management is not supported via API\"}"
            )
        end

        it 'fails to delete user' do
          delete '/fake-user'
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq(
              "{\"code\":20004,\"description\":\"User management is not supported via API\"}"
            )
        end
      end
    end
  end
end
