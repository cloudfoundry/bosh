require 'spec_helper'
require 'rack/test'

module Bosh::Director
  describe Api::UAAIdentityProvider do
    subject(:identity_provider) { Api::UAAIdentityProvider.new(provider_options) }
    let(:uaa_url) { 'http://localhost:8080/uaa' }
    let(:provider_options) { {'url' => uaa_url, 'key' => key} }
    let(:key) { 'symmetric tokenkey' }
    let(:app) { Support::TestController.new(double(:config, identity_provider: identity_provider)) }

    describe 'client info' do
      it 'contains type and options, but not secret key' do
        expect(identity_provider.client_info).to eq(
            'type' => 'uaa',
            'options' => {
              'url' => uaa_url
            }
          )
      end
    end

    context 'given an OAuth token' do
      let(:token_decoder) { instance_double('Bosh::Director::Api::UAATokenDecoder') }
      let(:auth_header) { 'bearer encodedtoken' }
      let(:request_env) { {'HTTP_AUTHORIZATION' => auth_header } }
      let(:audiences) { ['bosh_cli'] }
      let(:token_info) { double(:token_info) }

      before do
        expect(Bosh::Director::Api::UAATokenDecoder).to receive(:new).with(
          url: uaa_url, resource_id: audiences, symmetric_secret: key)
          .and_return(token_decoder)
      end

      context 'when using a valid token' do
        before do
          expect(token_decoder).to receive(:decode_token).with(auth_header)
            .and_return({ 'user_name' => 'marissa' })
        end

        it 'returns the username of the authenticated user' do
          expect(identity_provider.corroborate_user(request_env)).to eq('marissa')
        end

        context 'without symmetric key' do
          let(:key) { nil }

          before do
            provider_options.delete('key')
          end

          it 'returns the username of the authenticated user' do
            expect(identity_provider.corroborate_user(request_env)).to eq('marissa')
          end
        end
      end


      context 'when using a bad token' do
        before do
          expect(token_decoder).to receive(:decode_token)
            .and_raise(Bosh::Director::Api::UAATokenDecoder::BadToken)
        end

        it 'raises' do
          expect { identity_provider.corroborate_user(request_env) }
            .to raise_error(AuthenticationError)
        end
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
