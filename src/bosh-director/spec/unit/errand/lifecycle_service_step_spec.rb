require 'spec_helper'

module Bosh::Director
  describe Errand::LifecycleServiceStep do
    subject(:errand_step) do
      Errand::LifecycleServiceStep.new(
        runner,
        deployment_planner,
        errand_name,
        instance,
        logger
      )
    end

    let(:deployment_planner) { instance_double(DeploymentPlan::Planner, job_renderer: job_renderer) }
    let(:runner) { instance_double(Errand::Runner) }
    let(:errand_name) { 'errand_name' }
    let(:job_renderer) { instance_double(JobRenderer) }
    let(:errand_result) { Errand::Result.new(exit_code, nil, nil, nil) }
    let(:instance) { instance_double(DeploymentPlan::Instance) }

    describe '#run' do
      before do
        expect(job_renderer).to receive(:clean_cache!)
      end

      context 'when instance group is lifecycle service' do
        let(:is_errand) { false }
        let(:checkpoint_block) { Proc.new {} }

        context 'errand success' do
          let(:exit_code) { 0 }
          it 'returns the result string' do
            expect(runner).to receive(:run).with(instance, &checkpoint_block).
              and_return(errand_result)
            result = errand_step.run(&checkpoint_block)
            expect(result).to eq("Errand 'errand_name' completed successfully (exit code 0)")
          end
        end
      end
    end
  end
end
