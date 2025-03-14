require 'spec_helper'
require 'rack/test'

module Bosh
  module Director
    module Api
      module Controllers
        describe BaseController do
          include Rack::Test::Methods

          subject(:app) { Support::TestController.new(config, requires_authentication) }
          let(:config) { Config.load_hash(SpecHelper.director_config_hash) }

          let(:requires_authentication) { nil }
          let(:authenticates_successfully) { false }
          let(:identity_provider) { Support::TestIdentityProvider.new(config.get_uuid_provider) }

          before { allow(config).to receive(:identity_provider).and_return(identity_provider) }


          it 'sets the date header' do
            get '/test_route'
            expect(last_response.headers['Date']).not_to be_nil
          end

          it 'requires authentication' do
            get '/test_route'
            expect(last_response.status).to eq(401)
          end

          context 'when authorization is provided' do
            let(:authenticates_successfully) { true }
            before { basic_authorize 'admin', 'admin' }

            it 'passes the request env to the identity provider' do
              header('X-Test-Header', 'Value')
              get '/test_route'
              expect(identity_provider.request_env['HTTP_X_TEST_HEADER']).to eq('Value')
            end

            context 'when authenticating successfully' do

              it 'succeeds' do
                get '/test_route'
                expect(last_response.status).to eq(200)
                expect(last_response.body).to eq('Success with: admin')
              end
            end
          end

          context 'when failing to authenticate successfully' do
            let(:authenticates_successfully) { false }

            it 'rejects the request' do
              get '/test_route'
              expect(last_response.status).to eq(401)
            end
          end

          context 'when the controller does not require authentication' do
            let(:requires_authentication) { false }

            context 'when user provided credentials' do
              context 'when credentials are invalid' do
                before { basic_authorize 'invalid', 'invalid' }

                it 'returns controller response' do
                  get '/test_route'
                  expect(last_response.status).to eq(200)
                  expect(last_response.body).to eq('Success with: No user')
                end
              end

              context 'when credentials are valid' do
                before { basic_authorize 'admin', 'admin' }

                it 'returns controller response' do
                  get '/test_route'
                  expect(last_response.status).to eq(200)
                  expect(last_response.body).to eq('Success with: admin')
                end
              end
            end

            context 'when user did not provide credentials' do
              it 'skips authorization' do
                get '/test_route'
                expect(last_response.status).to eq(200)
                expect(last_response.body).to eq('Success with: No user')
              end

              it 'skips authorization for invalid routes' do
                get '/invalid_route'
                expect(last_response.status).to eq(404)
                expect(last_response.body).to eq("Endpoint '/invalid_route' not found.")
              end
            end
          end

          context 'when specifying X-Bosh-Context-Id' do
            let(:authenticates_successfully) { true }
            before { basic_authorize 'admin', 'admin' }

            it 'succeeds when the header is below 64 chars' do
              valid_context_id = "x" * 64
              header('X-Bosh-Context-Id', 'something')

              get '/test_route'
              expect(last_response.status).to eq(200)
            end

            it 'fails when the header is above 64 chars' do
              invalid_context_id = "x" * 65
              header('X-Bosh-Context-Id', invalid_context_id)

              get '/test_route'
              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)['code']).to eq(70010)
              expect(JSON.parse(last_response.body)['description']).to eq('X-Bosh-Context-Id cannot be more than 64 characters in length')
            end
          end
        end
      end
    end
  end
end
