require 'spec_helper'
require 'rack/test'

module Bosh::Director
  describe Api::UAAIdentityProvider do
    subject(:identity_provider) { Api::UAAIdentityProvider.new(key) }
    let(:key) { 'tokenkey' }
    let(:app) { Support::TestController.new(identity_provider) }
    let(:credentials) do
      {
        :admin => 'Basic YWRtaW46YWRtaW4=',
        :bogus => 'Basic YWRtaW46Ym9ndXM='
      }
    end

    context 'given an OAuth token' do
      let(:request_env) { {'HTTP_AUTHORIZATION' => "bearer #{encoded_token}"} }
      let(:encoded_token) { CF::UAA::TokenCoder.encode(token, skey: encoding_key) }
      let(:encoding_key) { key }
      let(:token) do
        {
          'jti' => 'd64209e4-d150-45c9-9569-a352f42149b1',
          'sub' => 'faf835ea-c582-4a28-b500-6e6ac1515690',
          'scope' => ['scim.userids', 'password.write', 'openid', 'cloud_controller.write', 'cloud_controller.read'],
          'client_id' => 'cf',
          'cid' => 'cf',
          'azp' => 'cf',
          'user_id' => 'faf835ea-c582-4a28-b500-6e6ac1515690',
          'user_name' => 'marissa',
          'email' => 'marissa@test.org',
          'iat' => 1424914647,
          'exp' => token_expiry_time,
          'iss' => 'http://localhost:8080/uaa/oauth/token',
          'aud' => audiences
        }
      end
      let(:token_expiry_time) { (Time.now + 1000).to_i }
      let(:audiences) { ['bosh'] }

      it 'returns the username of the authenticated user' do
        expect(identity_provider.corroborate_user(request_env)).to eq('faf835ea-c582-4a28-b500-6e6ac1515690')
      end

      context 'when the token is encoded with an incorrect key' do
        let(:encoding_key) { "another-key" }

        it 'raises' do
          expect { identity_provider.corroborate_user(request_env) }.to raise_error(AuthenticationError)
        end
      end

      context 'when the token has expired' do
        let(:token_expiry_time) { (Time.now - 1000).to_i }

        it 'raises' do
          expect { identity_provider.corroborate_user(request_env) }.to raise_error(AuthenticationError)
        end
      end

      context "when bosh isn't in the token's audience list" do
        let(:audiences) { ['nonbosh'] }

        it 'raises' do
          expect { identity_provider.corroborate_user(request_env) }.to raise_error(AuthenticationError)
        end
      end
    end

    context 'given valid HTTP basic authentication credentials' do
      let(:request_env) { {'HTTP_AUTHORIZATION' => credentials[:admin]} }

      it 'raises' do
        expect { identity_provider.corroborate_user(request_env) }.to raise_error(AuthenticationError)
      end
    end

    context 'given bogus HTTP basic authentication credentials' do
      let(:request_env) { {'HTTP_AUTHORIZATION' => credentials[:bogus]} }

      it 'raises' do
        expect { identity_provider.corroborate_user(request_env) }.to raise_error(AuthenticationError)
      end
    end

    describe 'a request (controller integration)' do
      include Rack::Test::Methods

      context 'given valid HTTP basic authentication credentials' do
        it 'is rejected' do
          basic_authorize 'admin', 'admin'
          get '/test_route'
          expect(last_response.status).to eq(401)
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
