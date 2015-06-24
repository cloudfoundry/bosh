require 'spec_helper'
require 'rack/test'

module Bosh::Director
  describe Api::UAAIdentityProvider do

    subject(:identity_provider) { Api::UAAIdentityProvider.new(provider_options, uuid_provider) }
    let(:provider_options) { {'url' => 'http://localhost:8080/uaa', 'symmetric_key' => skey, 'public_key' => pkey} }
    let(:uuid_provider) { instance_double(Api::DirectorUUIDProvider, 'uuid' => 'fake-director-uuid')}
    let(:skey) { 'tokenkey' }
    let(:pkey) { nil }
    let(:app) { Support::TestController.new(double(:config, identity_provider: identity_provider)) }
    let(:requested_access) { [] }
    let(:uaa_user) { identity_provider.get_user(request_env) }

    describe 'client info' do
      it 'contains type and options, but not secret key' do
        expect(identity_provider.client_info).to eq(
            'type' => 'uaa',
            'options' => {
              'url' => 'http://localhost:8080/uaa'
            }
          )
      end
    end

    context 'given an OAuth token' do
      let(:request_env) { {'HTTP_AUTHORIZATION' => "bearer #{encoded_token}"} }
      let(:token) do
        {
          'jti' => 'd64209e4-d150-45c9-9569-a352f42149b1',
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

        context 'when director is configured with the same symmetric key' do
          let(:skey) { 'symmetric-key' }

          context 'when user has bosh.admin' do

            it 'returns an authorized User with the username' do
              expect(uaa_user.username).to eq('marissa')
            end

            it 'has access' do
              expect(identity_provider.valid_access?(uaa_user, requested_access)).to be true
            end
          end

          context 'when user scope is bosh.<DIRECTOR-UUID>.admin' do
            context 'when uuid matches current director' do
              let(:scope) { ['bosh.fake-director-uuid.admin'] }

              it 'returns the username of the authenticated user' do
                expect(uaa_user.username).to eq('marissa')
              end
            end

            context 'when uuid does not match current director' do
              let(:scope) { ['bosh.other-director-uuid.admin'] }

              it 'returns false' do
                expect(identity_provider.valid_access?(uaa_user, requested_access)).to be false
              end
            end
          end

          context 'when user scope is not bosh.admin' do
            let(:scope) { [] }

            it 'returns false' do
              expect(identity_provider.valid_access?(uaa_user, requested_access)).to be false
            end

            context 'when requested_access is read' do
              let(:requested_access) { :read }

              it 'returns false' do
                expect(identity_provider.valid_access?(uaa_user, requested_access)).to be false
                expect(identity_provider.required_scopes(requested_access)).to eq(['bosh.admin', 'bosh.fake-director-uuid.admin', 'bosh.read', 'bosh.fake-director-uuid.read'])
              end

              context 'when user scope contains bosh.read' do
                let(:scope) { ['bosh.read'] }

                it 'returns user' do
                  expect(uaa_user.username).to eq('marissa')
                end
              end

              context 'when user scope contains bosh.<DIRECTOR-UUID>.read' do
                context 'when uuid matches current director' do
                  let(:scope) { ['bosh.fake-director-uuid.read'] }

                  it 'returns user' do
                    expect(uaa_user.username).to eq('marissa')
                  end
                end

                context 'when uuid does not match current director' do
                  let(:scope) { ['bosh.other-director-uuid.read'] }

                  it 'returns false' do
                    expect(identity_provider.valid_access?(uaa_user, requested_access)).to be false
                    expect(identity_provider.required_scopes(requested_access)).to eq(["bosh.admin", "bosh.fake-director-uuid.admin", "bosh.read", "bosh.fake-director-uuid.read"])
                  end
                end
              end
            end
          end
        end

        context 'when director is configured with another symmetric key' do
          let(:skey) { 'bad-key' }

          it 'raises an error' do
            expect{uaa_user.has_access?(requested_access)}.to raise_error(AuthenticationError)
          end
        end

        context 'when director does not have symmetric key' do
          let(:skey) { nil }

          it 'raises an error' do
            expect{uaa_user.has_access?(requested_access)}.to raise_error(AuthenticationError)
          end
        end

        context 'when the token has expired' do
          let(:token_expiry_time) { (Time.now - 1000).to_i }

          it 'raises an error' do
            expect{uaa_user.has_access?(requested_access)}.to raise_error(AuthenticationError)
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

          it 'has access' do
            expect(identity_provider.valid_access?(uaa_user, requested_access)).to be true
          end
        end

        context 'when director is configured with another public key' do
          let(:another_rsa_key) { OpenSSL::PKey::RSA.new(2048) }
          let(:pkey) { another_rsa_key.public_key }

          it 'raises an error' do
            expect { identity_provider.get_user(request_env) }.to raise_error(AuthenticationError)
          end
        end

        context 'when director does not have public key' do
          let(:pkey) { nil }

          it 'raises an error' do
            expect { identity_provider.get_user(request_env) }.to raise_error(AuthenticationError)
          end
        end

        context 'when the token has expired' do
          let(:token_expiry_time) { (Time.now - 1000).to_i }

          it 'raises' do
            expect {  identity_provider.get_user(request_env) }.to raise_error(AuthenticationError)
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
          expect(uaa_user.username).to eq('fake-client-id')
        end
      end
    end

    context 'when no Uaa token is given' do
      context 'given valid HTTP basic authentication credentials' do
        let(:request_env) { {'HTTP_AUTHORIZATION' => 'Basic YWRtaW46YWRtaW4='} }

        it 'raises' do
          expect { identity_provider.get_user(request_env) }.to raise_error(AuthenticationError)
        end
      end

      context 'given missing HTTP authentication credentials' do
        let(:request_env) { { } }

        it 'raises' do
          expect { identity_provider.get_user(request_env) }.to raise_error(AuthenticationError)
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
