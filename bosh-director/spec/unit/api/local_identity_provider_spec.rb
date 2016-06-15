require 'spec_helper'
require 'rack/test'

module Bosh::Director
  describe Api::LocalIdentityProvider do
    subject(:identity_provider) { Api::LocalIdentityProvider.new({'users' => users}) }
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
        local_user = identity_provider.get_user(request_env, {})
        expect(local_user.username).to eq('admin')
      end
    end

    context 'given bogus HTTP basic authentication credentials' do
      let(:request_env) { { 'HTTP_AUTHORIZATION' => credentials[:bogus] } }

      it 'raises' do
        expect {
          identity_provider.get_user(request_env, {})
        }.to raise_error(AuthenticationError)
      end
    end

    describe 'a request (controller integration)' do
      include Rack::Test::Methods

      let(:test_config) { SpecHelper.spec_get_director_config }
      let(:config) do
        config = Config.load_hash(test_config)
        identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
        allow(config).to receive(:identity_provider).and_return(identity_provider)
        config
      end
      let(:app) { Support::TestController.new(config) }

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
