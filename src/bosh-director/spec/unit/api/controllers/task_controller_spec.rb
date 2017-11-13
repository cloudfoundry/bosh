require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::TaskController do
      include Rack::Test::Methods

      subject(:app) { linted_rack_app(described_class.new(config)) }
      let(:config) { Config.load_hash(SpecHelper.spec_get_director_config) }

      it 'requires auth' do
        delete '/fake-id'
        expect(last_response.status).to eq(401)
      end

      it 'sets the date header' do
        delete '/'
        expect(last_response.headers['Date']).to_not be_nil
      end

      it 'allows Basic HTTP Auth with admin/admin credentials for ' +
             "test purposes (even though user doesn't exist)" do
        basic_authorize 'admin', 'admin'
        delete '/'
        expect(last_response.status).to_not eq(401)
      end

      describe 'DELETE /:id' do
        before { basic_authorize 'admin', 'admin' }

        context 'when the task does not exist' do
          it 'responds with status 404' do
            delete '/999999'
            expect(last_response.status).to eq(404)
          end
        end

        context 'when the task does exist' do
          let(:state) { :processing }
          let!(:task) {
            Models::Task.make(
              type: :update_deployment,
              state: state
            )
          }

          before { delete "/#{task.id}" }

          context 'when the task is not processing or queued' do
            let(:state) { :running }

            it 'responds with status 400' do
              expect(last_response.status).to eq(400)
            end

            it 'responds with expected body content' do
              expect(last_response.body).to eq("Cannot cancel task #{task.id}: invalid state (#{state})")
            end
          end

          context 'when the task is processing' do
            let(:state) { :processing }

            it 'updates the task to be state cancelling' do
              expect(task.reload.state).to eq('cancelling')
            end

            it 'responds with status 204' do
              expect(last_response.status).to eq(204)
            end
          end

          context 'when the task is queued' do
            let(:state) { :queued }

            it 'updates the task to be state cancelling' do
              expect(task.reload.state).to eq('cancelling')
            end

            it 'responds with status 204' do
              expect(last_response.status).to eq(204)
            end
          end
        end
      end
    end
  end
end
