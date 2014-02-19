require 'spec_helper'
require 'rack/test'
require 'bosh/director/api/controllers/errands_controller'

module Bosh::Director
  describe Api::Controllers::ErrandsController do
    include Rack::Test::Methods

    subject(:app) { described_class } # "app" is a Rack::Test hook

    before { Api::ResourceManager.stub(:new) }

    describe 'POST', '/deployments/:deployment_name/errands/:name/runs' do
      before { Config.base_dir = 'base_dir' }

      def perform
        post(
          '/deployments/fake-dep-name/errands/fake-errand-name/runs',
          JSON.dump({}),
          { 'CONTENT_TYPE' => 'application/json' },
        )
      end

      context 'authenticated access' do
        before { authorize 'admin', 'admin' }

        it 'enqueues a RunErrand task' do
          job_queue = instance_double('Bosh::Director::JobQueue')
          allow(JobQueue).to receive(:new).and_return(job_queue)

          task = instance_double('Bosh::Director::Models::Task', id: 1)
          expect(job_queue).to receive(:enqueue).with(
            'admin',
            Jobs::RunErrand,
            'run errand fake-errand-name from deployment fake-dep-name',
            ['fake-dep-name', 'fake-errand-name'],
          ).and_return(task)

          perform
        end

        it 'returns a task' do
          perform
          expect_redirect_to_queued_task(last_response)
        end
      end

      context 'accessing with invalid credentials' do
        before { authorize 'invalid-user', 'invalid-password' }

        it 'returns 401' do
          perform
          expect(last_response.status).to eq(401)
        end
      end

      context 'unauthenticated access' do
        it 'returns 401' do
          perform
          expect(last_response.status).to eq(401)
        end
      end
    end
  end
end
