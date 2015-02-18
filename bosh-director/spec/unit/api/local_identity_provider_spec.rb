require 'spec_helper'
require 'rack/test'

module Bosh::Director
  describe Api::LocalIdentityProvider do
    subject(:identity_provider) { Api::LocalIdentityProvider.new(Api::UserManager.new) }
    let(:app) { Support::TestController.new(identity_provider) }
    let(:credentials) do
      {
        :admin => 'Basic YWRtaW46YWRtaW4=',
        :bogus => 'Basic YWRtaW46Ym9ndXM='
      }
    end

    context 'given valid HTTP basic authentication credentials' do
      let(:request_env) { { 'HTTP_AUTHORIZATION' => credentials[:admin] } }

      it 'returns the username of the authenticated user' do
        expect(identity_provider.corroborate_user(request_env)).to eq('admin')
      end
    end

    context 'given bogus HTTP basic authentication credentials' do
      let(:request_env) { { 'HTTP_AUTHORIZATION' => credentials[:bogus] } }

      it 'raises' do
        expect {
          identity_provider.corroborate_user(request_env)
        }.to raise_error(AuthenticationError)
      end
    end

    describe 'a request (controller integration)' do
      include Rack::Test::Methods

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
