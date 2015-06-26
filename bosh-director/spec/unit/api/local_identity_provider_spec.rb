require 'spec_helper'
require 'rack/test'

module Bosh::Director
  describe Api::LocalIdentityProvider do
    subject(:identity_provider) { Api::LocalIdentityProvider.new({'users' => users}, 'fake-uuid') }
    let(:users) { [{'name' => 'admin', 'password' => 'admin'}] }
    let(:credentials) do
      {
        :admin => 'Basic YWRtaW46YWRtaW4=',
        :bogus => 'Basic YWRtaW46Ym9ndXM='
      }
    end

    describe 'client info' do
      it 'contains type and options, ' do
        expect(identity_provider.client_info).to eq(
            'type' => 'basic',
            'options' => {}
          )
      end
    end

    context 'given valid HTTP basic authentication credentials' do
      let(:request_env) { { 'HTTP_AUTHORIZATION' => credentials[:admin] } }

      it 'returns the username of the authenticated user' do
        local_user = identity_provider.get_user(request_env)
        expect(local_user.username).to eq('admin')
      end

      it 'validates user access' do
        local_user = identity_provider.get_user(request_env)
        expect(identity_provider.valid_access?(local_user, {})).to be(true)
      end
    end

    context 'given bogus HTTP basic authentication credentials' do
      let(:request_env) { { 'HTTP_AUTHORIZATION' => credentials[:bogus] } }

      it 'raises' do
        expect {
          identity_provider.get_user(request_env)
        }.to raise_error(AuthenticationError)
      end
    end

    describe 'a request (controller integration)' do
      include Rack::Test::Methods

      let(:app) { Support::TestController.new(double(:config, identity_provider: identity_provider)) }

      context 'given valid HTTP basic authentication credentials' do
        it 'is successful' do
          basic_authorize 'admin', 'admin'
          get '/test_route'
          expect(last_response.status).to eq(200)
        end
      end

      context 'given bogus HTTP basic authentication credentials' do
        it 'is rejected' do
          basic_authorize 'admin', 'bogus'
          get '/test_route'
          expect(last_response.status).to eq(401)
        end
      end
    end
  end
end
