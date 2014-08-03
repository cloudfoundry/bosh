require 'spec_helper'
require 'rack/test'
require 'bosh/director/api/controllers/errands_controller'

module Bosh::Director
  describe Api::Controllers::ErrandsController do
    include Rack::Test::Methods

    subject(:app) { described_class } # "app" is a Rack::Test hook

    before { Api::ResourceManager.stub(:new) }

    describe 'GET', '/deployments/:deployment_name/errands' do
      before { Config.base_dir = Dir.mktmpdir }
      after { FileUtils.rm_rf(Config.base_dir) }

      def perform
        get(
          '/deployments/fake-dep-name/errands',
          { 'CONTENT_TYPE' => 'application/json' },
        )
      end

      let!(:deployment_model) do
        Models::Deployment.make(
          name: 'fake-dep-name',
          manifest: "---\nmanifest: true",
        )
      end

      before { allow(Config).to receive(:event_log).with(no_args).and_return(event_log) }
      let(:event_log) { instance_double('Bosh::Director::EventLog::Log') }

      before { allow(Config).to receive(:logger).with(no_args).and_return(logger) }
      let(:logger) { Logger.new('/dev/null') }

      before do
        allow(DeploymentPlan::Planner).to receive(:parse).
          with({'manifest' => true}, {}, event_log, logger).
          and_return(deployment)
      end
      let(:deployment) { instance_double('Bosh::Director::DeploymentPlan::Planner', name: 'deployment') }

      before { allow(deployment).to receive(:jobs).and_return(jobs) }
      let(:jobs) { [
        instance_double('Bosh::Director::DeploymentPlan::Job', name: 'an-errand', can_run_as_errand?: true),
        instance_double('Bosh::Director::DeploymentPlan::Job', name: 'a-service', can_run_as_errand?: false),
        instance_double('Bosh::Director::DeploymentPlan::Job', name: 'another-errand', can_run_as_errand?: true),
      ]}

      context 'authenticated access' do
        before { authorize 'admin', 'admin' }

        it 'returns errands in deployment' do
          response = perform
          expect(response.body).to eq('[{"name":"an-errand"},{"name":"another-errand"}]')
          expect(last_response.status).to eq(200)
        end

      end

      context 'unauthenticated access' do
        it 'returns 401' do
          perform
          expect(last_response.status).to eq(401)
        end
      end
    end

    describe 'POST', '/deployments/:deployment_name/errands/:name/runs' do
      before { Config.base_dir = Dir.mktmpdir }
      after { FileUtils.rm_rf(Config.base_dir) }

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
