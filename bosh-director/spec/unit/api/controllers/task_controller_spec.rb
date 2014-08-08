require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::TaskController do
      include Rack::Test::Methods

      let!(:temp_dir) { Dir.mktmpdir}

      before do
        blobstore_dir = File.join(temp_dir, 'blobstore')
        FileUtils.mkdir_p(blobstore_dir)

        test_config = Psych.load(spec_asset('test-director-config.yml'))
        test_config['dir'] = temp_dir
        test_config['blobstore'] = {
          'provider' => 'local',
          'options' => {'blobstore_path' => blobstore_dir}
        }
        test_config['snapshots']['enabled'] = true
        Config.configure(test_config)
        @director_app = App.new(Config.load_hash(test_config))
      end

      after do
        FileUtils.rm_rf(temp_dir)
      end

      def app
        @rack_app ||= described_class.new
      end

      it 'requires auth' do
        delete '/'
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
            delete '/unknown-task'
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
