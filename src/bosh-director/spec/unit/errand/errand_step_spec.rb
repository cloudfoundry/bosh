require 'spec_helper'

module Bosh::Director
  describe Errand::ErrandStep do
    subject(:errand_step) do
      Errand::ErrandStep.new(
        runner,
        deployment_planner,
        errand_name,
        instance,
        instance_group,
        changes_exist,
        keep_alive,
        deployment_name,
        logger
      )
    end

    let(:deployment_planner) { instance_double(DeploymentPlan::Planner, job_renderer: job_renderer) }
    let(:runner) { instance_double(Errand::Runner) }
    let(:instance_group) { instance_double(DeploymentPlan::InstanceGroup, is_errand?: is_errand) }
    let(:errand_name) { 'errand_name' }
    let(:changes_exist) { false }
    let(:job_renderer) { instance_double(JobRenderer) }
    let(:deployment_name) { 'deployment-name' }
    let(:errand_result) { Errand::Result.new(exit_code, nil, nil, nil) }
    let(:instance) { instance_double(DeploymentPlan::Instance) }
    let(:keep_alive) { 'maybe' }

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

      context 'when instance group is lifecycle errand' do
        let(:is_errand) { true }
        let(:exit_code) { 0 }

        let(:job_manager) { instance_double(Errand::JobManager) }
        let(:errand_instance_updater) { instance_double(Errand::ErrandInstanceUpdater) }

        it 'creates the vm, then runs the errand' do
          expect(Errand::JobManager).to receive(:new).with(deployment_planner, instance_group, logger).and_return(job_manager)
          expect(Errand::ErrandInstanceUpdater).to receive(:new)
               .with(job_manager, logger, errand_name, deployment_name)
               .and_return(errand_instance_updater)
          expect(errand_instance_updater).to receive(:with_updated_instances).with(instance_group, keep_alive) do |&blk|
            blk.call
          end
          expect(runner).to receive(:run).and_return(errand_result)
          result = errand_step.run(&lambda {})
          expect(result).to eq("Errand 'errand_name' completed successfully (exit code 0)")
        end
      end
    end
  end
end
