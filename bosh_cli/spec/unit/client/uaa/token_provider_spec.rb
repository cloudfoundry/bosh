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

  let(:password_token) do
    uaa_token_info('bosh_cli', expiration_time, 'password-refresh-token')
  end

  let(:client_token) do
    uaa_token_info(encoded_client_id, expiration_time, nil)
  end

  let(:expiration_time) { uaa_token_expiration_time }

  let(:encoded_client_id) { 'test' }

  def simulate_password_login
    config.set_credentials('fake-target', {'access_token' => password_token.auth_header, 'refresh_token' => password_token.info[:refresh_token]})
  end

  describe '#token' do
    context 'when client credentials are provided' do
      let(:env) do
        {
          'BOSH_CLIENT' => 'test',
          'BOSH_CLIENT_SECRET' => 'secret',
        }
      end

      it 'logs in' do
        expect(token_issuer).to receive(:client_credentials_grant).and_return(client_token)
        expect(token_provider.token).to eq(client_token.auth_header)
      end

      context 'when previously logged in with password credentials' do
        before do
          simulate_password_login
        end

        it 'logs in with the client credentials' do
          expect(token_issuer).to receive(:client_credentials_grant).and_return(client_token)
          expect(token_provider.token).to eq(client_token.auth_header)
        end
      end

      context 'when called second time' do
        let(:second_client_token) { uaa_token_info(encoded_client_id, expiration_time, 'second-refresh-token') }

        before do
          Timecop.freeze
          allow(token_issuer).to receive(:client_credentials_grant).once.and_return(client_token, second_client_token)
          token_provider.token
        end

        it 'reuses the token if it is not expired' do
          expect(token_provider.token).to eq(client_token.auth_header)
        end

        context 'when token is expired' do
          before do
            Timecop.travel(expiration_time + 1)
          end

          it 'logs in again' do
            expect(token_provider.token).to eq(second_client_token.auth_header)
          end
        end
      end
    end

    context 'when client credentials are not provided' do
      context 'when user was logged in' do
        before do
          simulate_password_login
        end

        context 'when config token is not expired' do
          it 'uses token from config' do
            expect(token_provider.token).to eq(password_token.auth_header)
          end
        end

        context 'when config token expired' do
          before do
            Timecop.travel(expiration_time + 1)
          end

          it 'refreshes the token' do
            refreshed_token_info = CF::UAA::TokenInfo.new(
              token_type: 'bearer',
              access_token: 'refreshed-token'
            )
            expect(token_issuer).to receive(:refresh_token_grant).with(password_token.info[:refresh_token]).and_return(refreshed_token_info)
            expect(token_provider.token).to eq('bearer refreshed-token')
          end
        end
      end

      context 'when no login (client or password) has previously occurred' do
        it 'returns nil' do
          expect(token_provider.token).to eq(nil)
        end
      end
    end
  end
end
