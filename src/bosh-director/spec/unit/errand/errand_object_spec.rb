require 'spec_helper'

module Bosh::Director
  describe Errand::ErrandObject do
    subject(:errand_object) do
      Errand::ErrandObject.new(runner, deployment_planner, errand_name, instance_group, use_existing_vm, changes_exist, deployment_name, logger)
    end
    let(:deployment_planner) do
      instance_double(DeploymentPlan::Planner, job_renderer: job_renderer)
    end
    let(:runner) { instance_double(Errand::Runner) }
    let(:instance_group) { instance_double(DeploymentPlan::InstanceGroup) }
    let(:errand_name) { 'errand_name' }
    let(:use_existing_vm) { true }
    let(:changes_exist) { true }
    let(:job_renderer) { instance_double(JobRenderer) }
    let(:deployment_name) { 'deployment-name' }
    let(:errand_result) { Errand::Result.new(exit_code, nil, nil, nil) }

    describe '#run' do
      before do
        expect(job_renderer).to receive(:clean_cache!)
      end

      context 'when using an existing vm' do
        context 'errand success' do
          let(:exit_code) { 0 }
          it 'returns the result string' do
            expect(runner).to receive(:run).and_return(errand_result)
            result = errand_object.run(false, false, &lambda { })
            expect(result).to eq("Errand 'errand_name' completed successfully (exit code 0)")
          end
        end

        context 'when the task is cancelled' do
          it 'cancels the errand run and raises the error' do
            expect(runner).to(receive(:run)) { |&cancel_block| cancel_block.call }
            expect(runner).to receive(:cancel)
            expect {
              errand_object.run(false, false, &lambda{ raise TaskCancelled })
            }.to raise_error(TaskCancelled)
          end
        end
      end
    end
  end
end
