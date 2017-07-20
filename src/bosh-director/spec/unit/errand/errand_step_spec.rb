require 'spec_helper'

module Bosh::Director
  describe Errand::ErrandStep do
    subject(:errand_step) do
      Errand::ErrandStep.new(
        runner,
        deployment_planner,
        errand_name,
        instance_group,
        changes_exist,
        deployment_name,
        logger
      )
    end
    let(:deployment_planner) { instance_double(DeploymentPlan::Planner, job_renderer: job_renderer) }
    let(:runner) { instance_double(Errand::Runner) }
    let(:instance_group) { instance_double(DeploymentPlan::InstanceGroup, is_errand?: is_errand) }
    let(:errand_name) { 'errand_name' }
    let(:changes_exist) { true }
    let(:job_renderer) { instance_double(JobRenderer) }
    let(:deployment_name) { 'deployment-name' }
    let(:errand_result) { Errand::Result.new(exit_code, nil, nil, nil) }

    describe '#run' do
      before do
        expect(job_renderer).to receive(:clean_cache!)
      end

      context 'when instance group is lifecycle service' do
        let(:is_errand) { false }

        context 'errand success' do
          let(:exit_code) { 0 }
          it 'returns the result string' do
            expect(runner).to receive(:run).and_return(errand_result)
            result = errand_step.run(false, false, &lambda {})
            expect(result).to eq("Errand 'errand_name' completed successfully (exit code 0)")
          end
        end

        context 'when the task is cancelled' do
          it 'cancels the errand run and raises the error' do
            expect(runner).to(receive(:run)) { |&cancel_block| cancel_block.call }
            expect(runner).to receive(:cancel)
            expect {
              errand_step.run(false, false, &lambda { raise TaskCancelled })
            }.to raise_error(TaskCancelled)
          end
        end
      end

      context 'when instance group is lifecycle errand' do
        let(:is_errand) { true }
        let(:exit_code) { 0 }
        let(:keep_alive) { 'perhaps' }
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
          result = errand_step.run(keep_alive, false, &lambda {})
          expect(result).to eq("Errand 'errand_name' completed successfully (exit code 0)")
        end
      end
    end
  end
end
