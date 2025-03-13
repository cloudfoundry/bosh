require 'spec_helper'
require 'rack/test'

module Bosh::Director
  describe Api::UAAIdentityProvider do

    before do
      FactoryBot.create(:models_director_attribute, name: 'uuid', value: 'fake-director-uuid')
    end

    subject(:identity_provider) { Api::UAAIdentityProvider.new(provider_options) }
    let(:provider_options) do
      { 'url' => 'http://localhost:8080/uaa', 'symmetric_key' => skey, 'public_key' => pkey }
    end
    let(:skey) { 'tokenkey' }
    let(:pkey) { nil }
    let(:test_config) { SpecHelper.director_config_hash }
    let(:config) do
      config = Config.load_hash(test_config)
      allow(config).to receive(:identity_provider).and_return(identity_provider)
      config
    end
    let(:app) { Support::TestController.new(config) }
    let(:requested_access) { :read }
    let(:uaa_user) { identity_provider.get_user(request_env, options) }
    let(:options) do
      {}
    end

    describe 'client info' do
      it 'contains type and options, but not secret key' do
        expect(identity_provider.client_info).to eq(
            'type' => 'uaa',
            'options' => {
              'url' => 'http://localhost:8080/uaa',
              'urls' => ['http://localhost:8080/uaa']
            }
          )
      end
    end

    describe 'initialize' do
      context 'if options contains url and urls' do
        let(:provider_options) do
          { 'url' => 'http://one', 'urls' => ['http://one', 'http://two'] }
        end

        it 'throws exception' do
          expect { identity_provider }.to raise_error(ValidationExtraField)
        end
      end

      context 'if options contain url' do
        let(:provider_options) do
          { 'url' => 'http://one' }
        end

        it 'sets url and urls in client_info' do
          expect(identity_provider.client_info['options']['url']).to eq('http://one')
          expect(identity_provider.client_info['options']['urls']).to eq(['http://one'])
        end
      end

      context 'if options contain urls' do
        let(:provider_options) do
          { 'urls' => ['http://one', 'http://two'] }
        end

        it 'sets url and urls in client_info' do
          expect(identity_provider.client_info['options']['url']).to eq('http://one')
          expect(identity_provider.client_info['options']['urls']).to eq(['http://one', 'http://two'])
        end
      end
    end

    context 'given an OAuth token' do
      let(:jti) { 'd64209e4-d150-45c9-9569-a352f42149b1' }
      let(:request_env) do
        { 'HTTP_AUTHORIZATION' => "bearer #{encoded_token}" }
      end
      let(:token) do
        {
          'jti' => jti,
          'sub' => 'faf835ea-c582-4a28-b500-6e6ac1515690',
          'scope' => scope,
          'client_id' => 'cf',
          'cid' => 'cf',
          'azp' => 'cf',
          'user_id' => 'faf835ea-c582-4a28-b500-6e6ac1515690',
          'user_name' => 'marissa',
          'email' => 'marissa@test.org',
          'iat' => Time.now.to_i,
          'exp' => token_expiry_time,
          'iss' => 'http://localhost:8080/uaa/oauth/token',
          'aud' => ['bosh_cli']
        }
      end
      let(:scope) { ['scim.userids', 'password.write', 'openid', 'bosh.admin'] }

      let(:token_expiry_time) { (Time.now + 1000).to_i }

      context 'when token is encoded with symmetric key' do
        let(:encoded_token) { CF::UAA::TokenCoder.encode(token, skey: 'symmetric-key') }

        context 'when director is configured with another symmetric key' do
          let(:skey) { 'bad-key' }

          it 'raises an error' do
            expect{uaa_user}.to raise_error(AuthenticationError)
          end
        end

        context 'when director does not have symmetric key' do
          let(:skey) { nil }

          it 'raises an error' do
            expect{uaa_user}.to raise_error(AuthenticationError)
          end
        end

        context 'when the token is a refresh token' do
          let(:jti) { 'd64209e4-d150-45c9-9569-a352f42149b1-r' }

          it 'returns an authentication error' do
            expect { uaa_user }.to raise_error(AuthenticationError)
          end
        end

        context 'when the token has expired' do
          let(:token_expiry_time) { (Time.now - 1000).to_i }

          it 'raises an error' do
            expect{uaa_user}.to raise_error(AuthenticationError)
          end
        end
      end

      context 'when token is encoded with asymmetric key' do
        let(:rsa_key) { OpenSSL::PKey::RSA.new(2048) }
        let(:encoded_token) { CF::UAA::TokenCoder.encode(token, {pkey: rsa_key.to_pem, algorithm: 'RS256'}) }

        context 'when director is configured with the public key that match asymmetric key' do
          let(:pkey) { rsa_key.public_key }

          it 'returns user' do
            expect(uaa_user.username).to eq('marissa')
          end
        end

        context 'when director is configured with another public key' do
          let(:another_rsa_key) { OpenSSL::PKey::RSA.new(2048) }
          let(:pkey) { another_rsa_key.public_key }

          it 'raises an error' do
            expect { uaa_user }.to raise_error(AuthenticationError)
          end
        end

        context 'when director does not have public key' do
          let(:pkey) { nil }

          it 'raises an error' do
            expect { uaa_user }.to raise_error(AuthenticationError)
          end
        end

        context 'when the token has expired' do
          let(:token_expiry_time) { (Time.now - 1000).to_i }

          it 'raises' do
            expect {  uaa_user }.to raise_error(AuthenticationError)
          end
        end
      end

      context 'when token does not have user_name' do
        let(:encoded_token) { CF::UAA::TokenCoder.encode(token, skey: skey) }

        before do
          token.delete('user_name')
          token['client_id'] = 'fake-client-id'
        end

        it 'returns client id' do
          expect(uaa_user.username_or_client).to eq('fake-client-id')
        end
      end
    end

    context 'when no Uaa token is given' do
      context 'given valid HTTP basic authentication credentials' do
        let(:request_env) do
          { 'HTTP_AUTHORIZATION' => 'Basic YWRtaW46YWRtaW4=' }
        end

        it 'raises' do
          expect { uaa_user }.to raise_error(AuthenticationError)
        end
      end

      context 'given missing HTTP authentication credentials' do
        let(:request_env) do
          {}
        end

        it 'raises' do
          expect { uaa_user }.to raise_error(AuthenticationError)
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
end
