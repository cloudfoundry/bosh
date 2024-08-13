require 'spec_helper'

module Bosh::Director
  describe Jobs::CloudCheck::ApplyResolutions do
    before do
      FactoryBot.create(:models_deployment, name: 'deployment')
      allow(ProblemResolver).to receive_messages(new: resolver)
    end

    describe 'DJ job class expectations' do
      let(:job_type) { :cck_apply }
      let(:queue) { :normal }
      it_behaves_like 'a DJ job'
    end

    let(:resolutions) do
      { 1 => 'delete_disk', 2 => 'ignore' }
    end
    let(:max_in_flight_overrides) do
      { 'diego_cell' => '100%', 'router' => 5 }
    end
    let(:normalized_max_in_flight_overrides) do
      { 'diego_cell' => '100%', 'router' => '5' }
    end
    let(:normalized_resolutions) do
      { '1' => 'delete_disk', '2' => 'ignore' }
    end
    let(:job) { described_class.new('deployment', resolutions, max_in_flight_overrides) }
    let(:resolver) { instance_double('Bosh::Director::ProblemResolver') }
    let(:deployment) { Models::Deployment.first }

    describe '#perform' do
      context 'when resolution succeeds' do
        it 'should normalize the problem ids and overrides' do
          allow(job).to receive(:with_deployment_lock).and_yield

          expect(resolver).to receive(:apply_resolutions).with(normalized_resolutions, normalized_max_in_flight_overrides)

          job.perform
        end

        it 'obtains a deployment lock' do
          expect(job).to receive(:with_deployment_lock).with(deployment).and_yield

          allow(resolver).to receive(:apply_resolutions)

          job.perform
        end

        it 'applies the resolutions' do
          allow(job).to receive(:with_deployment_lock).and_yield

          expect(resolver).to receive(:apply_resolutions).and_return(1)

          expect(job.perform).to eq('1 resolved')
        end

        it 'runs the post-deploy script' do
          allow(job).to receive(:with_deployment_lock).and_yield
          allow(resolver).to receive(:apply_resolutions)

          expect(Bosh::Director::PostDeploymentScriptRunner).to receive(:run_post_deploys_after_resurrection).with(deployment)
          job.perform
        end

      end

      context 'when resolution fails' do
        it 'raises an error' do
          allow(job).to receive(:with_deployment_lock).and_yield

          expect(resolver).to receive(:apply_resolutions).and_return([1, 'error message'])

          expect {
            job.perform
          }.to raise_error(Bosh::Director::ProblemHandlerError)
        end

        it 'does not run the post-deploy script' do
          allow(job).to receive(:with_deployment_lock).and_yield

          expect(resolver).to receive(:apply_resolutions).and_return([1, 'error message'])

          expect(Bosh::Director::PostDeploymentScriptRunner).to_not receive(:run_post_deploys_after_resurrection)

          expect {
            job.perform
          }.to raise_error(Bosh::Director::ProblemHandlerError)
        end
      end
    end
  end
end
