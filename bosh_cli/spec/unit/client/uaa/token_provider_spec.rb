require 'spec_helper'

describe Bosh::Cli::Client::Uaa::TokenProvider do
  include FakeFS::SpecHelpers
  include Support::UaaHelpers

  subject(:token_provider) { described_class.new(auth_info, config, token_decoder, 'fake-target') }
  let(:config) { Bosh::Cli::Config.new('fake-config') }
  let(:auth_info) { Bosh::Cli::Client::Uaa::AuthInfo.new(director, env, 'fake-cert') }
  let(:env) { {} }
  let(:director) { Bosh::Cli::Client::Director.new('http://127.0.0.1') }
  before do
    allow(director).to receive(:get_status).and_return(
      {'user_authentication' => {'type' => 'uaa', 'options' => {'url' => 'https://uaa-url'}}}
    )
  end

  let(:token_decoder) { Bosh::Cli::Client::Uaa::TokenDecoder.new }

  let(:token_issuer) { instance_double(CF::UAA::TokenIssuer) }
  before do
    allow(CF::UAA::TokenIssuer).to receive(:new).and_return(token_issuer)
  end

  let(:token) do
    uaa_token_info(encoded_client_id, expiration_time)
  end

  let(:expiration_time) { Time.now.to_i + expiration_deadline + 10 }
  let(:expiration_deadline) { Bosh::Cli::Client::Uaa::AccessInfo::EXPIRATION_DEADLINE_IN_SECONDS }

  let(:encoded_client_id) { 'test' }

  describe '#token' do
    context 'when client credentials are provided' do
      let(:env) do
        {
          'BOSH_CLIENT' => 'test',
          'BOSH_CLIENT_SECRET' => 'secret',
        }
      end

      context 'when config contains access token' do
        before do
          config.set_credentials('fake-target', { 'access_token' => token.auth_header })
        end

        context 'when token in config matches client credentials' do
          it 'uses token in config' do
            expect(token_provider.token).to eq(token.auth_header)
          end

          context 'when config token expired' do
            let(:expiration_time) { Time.now.to_i - expiration_deadline - 10 }

            it 'refreshes the token' do
              refreshed_token = CF::UAA::TokenInfo.new(
                token_type: 'bearer',
                access_token: 'refreshed-token'
              )
              expect(token_issuer).to receive(:client_credentials_grant).and_return(refreshed_token)
              expect(token_provider.token).to eq('bearer refreshed-token')
            end
          end
        end

        context 'when token in config does not match client credentials' do
          let(:encoded_client_id) { 'invalid' }

          it 'logs in' do
            expect(token_issuer).to receive(:client_credentials_grant).and_return(token)
            expect(token_provider.token).to eq(token.auth_header)
          end
        end
      end

      context 'when config does not contain access token' do
        it 'logs in' do
          expect(token_issuer).to receive(:client_credentials_grant).and_return(token)
          expect(token_provider.token).to eq(token.auth_header)
        end
      end
    end

    context 'when client credentials are not provided' do
      context 'when config contains access token' do
        before do
          config.set_credentials('fake-target', {'access_token' => token.auth_header})
        end

        context 'when config token is not expired' do
          it 'uses token from config' do
            expect(token_provider.token).to eq(token.auth_header)
          end
        end

        context 'when config token expired' do
          let(:expiration_time) { Time.now.to_i + expiration_deadline - 10 }

          it 'refreshes the token' do
            refreshed_token = CF::UAA::TokenInfo.new(
              token_type: 'bearer',
              access_token: 'refreshed-token'
            )
            expect(token_issuer).to receive(:refresh_token_grant).and_return(refreshed_token)
            expect(token_provider.token).to eq('bearer refreshed-token')
          end
        end
      end

      context 'when config does not contain access token' do
        it 'returns nil' do
          expect(token_provider.token).to eq(nil)
        end
      end
    end
  end
end
