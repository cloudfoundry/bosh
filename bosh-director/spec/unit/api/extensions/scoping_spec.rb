require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Extensions::Scoping do
      include Rack::Test::Methods

      let(:app) { Support::TestController.new(double(:config, identity_provider: identity_provider), true) }
      let(:identity_provider) { Support::TestIdentityProvider.new }

      describe 'scope' do
        context 'when authorizaion is provided'do
          before { basic_authorize('admin', 'admin') }

          context 'when scope is defined on a route' do
            it 'passes it to identity provider' do
              get '/read'
              expect(identity_provider.scope).to eq(:read)
            end
          end

          context 'when scope is not defined on a route' do
            it 'uses default scope' do
              get '/test_route'
              expect(identity_provider.scope).to eq(:write)
            end
          end

          context 'when scope is set for request params' do
            it 'uses defined scope on specified param' do
              get '/params?name=test'
              expect(identity_provider.scope).to eq(:read)
            end

            it 'uses default scope on non-specified param' do
              get '/params?name=other'
              expect(identity_provider.scope).to eq(:write)
            end
          end

          context 'when user does not have access' do
            before { basic_authorize('reader', 'reader') }

            it 'returns a detailed error message' do
              get '/test_route'
              expect(last_response.status).to eq(401)
              expect(last_response.body).to include("Not authorized: '/test_route' requires one of the scopes: fake-valid-scope-1, fake-valid-scope-2")
            end

            context 'when identity provider is not UAA' do
              let(:identity_provider) { Api::LocalIdentityProvider.new({}, {}) }

              it 'return generic error messsage' do
                get '/test_route'
                expect(last_response.status).to eq(401)
                expect(last_response.body).to eq("Not authorized: '/test_route'\n")
              end
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

            let(:app) { NonsecureController.new(double(:config, identity_provider: identity_provider)) }

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
