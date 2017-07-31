require 'spec_helper'

module Bosh::Director
  describe Errand::LifecycleErrandStep do
    subject(:errand_step) do
      Errand::LifecycleErrandStep.new(
        runner,
        deployment_planner,
        errand_name,
        instance,
        instance_group,
        skip_errand,
        keep_alive,
        deployment_name,
        logger
      )
    end

    let(:deployment_planner) { instance_double(DeploymentPlan::Planner, template_blob_cache: template_blob_cache) }
    let(:runner) { instance_double(Errand::Runner) }
    let(:instance_group) { instance_double(DeploymentPlan::InstanceGroup, is_errand?: true) }
    let(:errand_name) { 'errand_name' }
    let(:skip_errand) { false }
    let(:template_blob_cache) { instance_double(Bosh::Director::Core::Templates::TemplateBlobCache) }
    let(:deployment_name) { 'deployment-name' }
    let(:errand_result) { Errand::Result.new(exit_code, nil, nil, nil) }
    let(:instance) { instance_double(DeploymentPlan::Instance) }
    let(:keep_alive) { 'maybe' }
    let(:instance_group_manager) { instance_double(Errand::InstanceGroupManager) }
    let(:errand_instance_updater) { instance_double(Errand::ErrandInstanceUpdater) }

    before do
      allow(Errand::InstanceGroupManager).to receive(:new)
                                               .with(deployment_planner, instance_group, logger)
                                               .and_return(instance_group_manager)
      allow(Errand::ErrandInstanceUpdater).to receive(:new)
                                                .with(instance_group_manager, logger, errand_name, deployment_name)
                                                .and_return(errand_instance_updater)
    end

    describe '#prepare' do
      context 'when keep alive is true' do
        let(:keep_alive) { true }
        it 'updates instances with keep alive' do
          expect(errand_instance_updater).to receive(:create_vms).with(keep_alive)
          errand_step.prepare
        end
      end

      context 'when keep alive is false' do
        let(:keep_alive) { false }
        it 'updates instances without keep alive' do
          expect(errand_instance_updater).to receive(:create_vms).with(keep_alive)
          errand_step.prepare
        end
      end

      context 'when creating instances fails' do
        it 'should raise' do
          expect(errand_instance_updater).to receive(:create_vms).and_raise("OMG")
          expect { errand_step.prepare }.to raise_error("OMG")
        end
      end

      context 'when there are no changes' do
        let(:skip_errand) { true }
        it 'should not update the instances' do
          expect(errand_instance_updater).not_to receive(:create_vms)
          errand_step.prepare
        end
      end
    end

    describe '#run' do
      before do
        expect(template_blob_cache).to receive(:clean_cache!)
      end

      context 'when instance group is lifecycle errand' do
        let(:exit_code) { 0 }

        it 'then runs the errand' do
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
