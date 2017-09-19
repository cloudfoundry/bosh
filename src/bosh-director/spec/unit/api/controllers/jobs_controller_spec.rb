require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::JobsController do
      include Rack::Test::Methods

      subject(:app) { described_class.new(config) }
      let(:config) do
        config = Config.load_hash(SpecHelper.spec_get_director_config)
        identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
        allow(config).to receive(:identity_provider).and_return(identity_provider)
        config
      end

      before { App.new(config) }

      before do
        release_1 = Models::Release.make(:name => 'test-release-1')
        release_2 = Models::Release.make(:name => 'test-release-2')
        Models::Template.make(
          name: 'test-job-1',
          release: release_1,
          fingerprint: 'deadbeef',
          spec: {'some' => 'spec-1'},
        )
        Models::Template.make(
          name: 'test-job-2',
          release: release_2,
          fingerprint: 'deadchicken',
          spec: {'some' => 'spec-2'},
        )
      end

      it 'requires auth' do
        get '/'
        expect(last_response.status).to eq(401)
      end

      it 'sets the date header' do
        get '/'
        expect(last_response.headers['Date']).not_to be_nil
      end

      describe 'GET', '/' do
        context 'when user has admin access' do
          before { authorize 'admin', 'admin' }

          context 'when all request params are present' do

            it 'returns the job details' do
              get '/?release_name=test-release-1&name=test-job-1&fingerprint=deadbeef'
              expect(last_response.body).to eq(JSON.generate([{
                name: 'test-job-1',
                fingerprint: 'deadbeef',
                spec: {'some' => 'spec-1'},
              }]))
            end

            context 'when release_name does not exist' do
              it 'returns 404' do
                get '/?release_name=bad&name=test-job-1&fingerprint=deadbeef'
                expect(last_response.status).to eq(404)
              end
            end

            context 'when name does not exist' do
              it 'returns 404' do
                get '/?release_name=test-release-1&name=bad&fingerprint=deadbeef'
                expect(last_response.status).to eq(404)
              end
            end

            context 'when fingerprint does not exist' do
              it 'returns 404' do
                get '/?release_name=test-release-1&name=test-job-1&fingerprint=bad'
                expect(last_response.status).to eq(404)
              end
            end
          end

          context 'when any request params are missing' do
            it 'returns a 400' do
              get '/?name=test-job-1&fingerprint=deadbeef'
              expect(last_response.status).to eq(400)
            end
          end
        end

        context 'when user has read access' do
          before { authorize 'reader', 'reader' }

          context 'when all request params are present' do
            it 'returns the job details' do
              get '/?release_name=test-release-1&name=test-job-1&fingerprint=deadbeef'
              expect(last_response.body).to eq(JSON.generate([{
                name: 'test-job-1',
                fingerprint: 'deadbeef',
                spec: {'some' => 'spec-1'},
              }]))
            end
          end

          context 'when user provides no parameters' do
            it 'returns an array of each job name, fingerprint, and spec' do
              get '/'
              expect(last_response.body).to eq(JSON.generate([{
                name: 'test-job-1',
                fingerprint: 'deadbeef',
                spec: {'some' => 'spec-1'},
              }, {
                  name: 'test-job-2',
                  fingerprint: 'deadchicken',
                  spec: {'some' => 'spec-2'},
              }]))
            end
          end
        end

        context 'when user has director level read access' do
          before { authorize 'director-reader', 'director-reader' }

          context 'when all request params are present' do
            it 'returns the job details' do
              get '/?release_name=test-release-1&name=test-job-1&fingerprint=deadbeef'
              expect(last_response.body).to eq(JSON.generate([{
                name: 'test-job-1',
                fingerprint: 'deadbeef',
                spec: {'some' => 'spec-1'},
              }]))
            end
          end
        end

        context 'when user has insufficient privileges' do
          before { authorize 'dev-team-member', 'dev-team-member' }

          context 'when all request params are present' do
            it 'returns 401' do
              get '/?release_name=test-release-1&name=test-job-1&fingerprint=deadbeef'
              expect(last_response.status).to eq(401)
            end
          end

          context 'when user provides no parameters' do
            it 'returns 401' do
              get '/'
              expect(last_response.status).to eq(401)
            end
          end
        end
      end
    end
  end
end
