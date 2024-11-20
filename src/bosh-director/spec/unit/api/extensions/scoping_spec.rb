require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Extensions::Scoping do
      include Rack::Test::Methods

      let(:config) do
        config = Config.load_hash(SpecHelper.director_config_hash)
        identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
        allow(config).to receive(:identity_provider).and_return(identity_provider)
        config
      end
      let(:app) { Support::TestController.new(config, true) }

      describe 'scope' do
        context 'when authorization is provided'do
          context 'as admin'
            before { basic_authorize('admin', 'admin') }

            context 'when scope is defined on a route' do
              it 'passes it to identity provider' do
                expect(get('/read').status).to eq(200)
              end
            end

            context 'when scope is not defined on a route' do
              it 'uses default scope' do
                expect(get('/test_route').status).to eq(200)
              end
            end

            context 'when scope is set for request params' do
              it 'uses defined scope on specified param' do
                expect(get('/params?name=test').status).to eq(200)
              end

              it 'uses default scope on non-specified param' do
                expect(get('/params?name=other').status).to eq(200)
              end
            end
        end

        context 'when user does not have access' do
          before { basic_authorize('reader', 'reader') }

          it 'returns a detailed error message' do
            get '/test_route'
            expect(last_response.status).to eq(401)
            expect(last_response.body).to include('Require one of the scopes:')
          end

          context 'when scope is set for request params' do
            it 'uses defined scope on specified param' do
              expect(get('/params?name=test').status).to eq(200)
            end

            it 'uses default scope on non-specified param' do
              expect(get('/params?name=other').status).to eq(401)
            end
          end

          context 'when identity provider is not UAA' do
            let(:identity_provider) { Api::LocalIdentityProvider.new({}) }

            it 'return generic error message' do
              get '/test_route'
              expect(last_response.status).to eq(401)
              expect(last_response.body).to include('Require one of the scopes:')
            end
          end
        end

        context 'when authorization is not provided' do
          context 'when controller does not require authorization' do
            class NonsecureController < Bosh::Director::Api::Controllers::BaseController
              def requires_authentication?
                false
              end

              get '/' do
                'Success'
              end
            end

            let(:app) { NonsecureController.new(config) }

            it 'succeeds' do
              get '/'
              expect(last_response.status).to eq(200)
              expect(last_response.body).to include('Success')
            end
          end

          context 'when controller requires authorization' do
            it 'returns non-authorized' do
              get '/read'
              expect(last_response.status).to eq(401)
              expect(last_response.body).to include("Not authorized: '/read'\n")
            end
          end
        end
      end
    end
  end
end
