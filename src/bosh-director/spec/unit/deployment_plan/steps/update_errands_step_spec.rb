require 'spec_helper'
require 'bosh/director/deployment_plan/multi_job_updater'
require 'bosh/director/job_updater'

module Bosh::Director
  module DeploymentPlan::Steps
    describe UpdateErrandsStep do
      subject { DeploymentPlan::Steps::UpdateErrandsStep.new(base_job, deployment_plan) }
      let(:base_job) { Jobs::BaseJob.new }
      let(:event_log) { Config.event_log }

      let(:errand_instance) { instance_double('Bosh::Director::DeploymentPlan::Instance') }
      let(:errand_instance_plan) { instance_double('Bosh::Director::DeploymentPlan::InstancePlan', instance: errand_instance) }
      let(:errand_instance_group) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', unignored_instance_plans: [errand_instance_plan]) }

      let(:ignored_errand_instance) { instance_double('Bosh::Director::DeploymentPlan::Instance') }
      let(:ignored_instance_plan) { instance_double('Bosh::Director::DeploymentPlan::InstancePlan', instance: ignored_errand_instance) }
      let(:ignored_errand_instance_group) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', unignored_instance_plans: []) }

      let(:event_log_stage) { instance_double('Bosh::Director::EventLog::Stage') }
      let(:ip_provider) { instance_double('Bosh::Director::DeploymentPlan::IpProvider') }

      let(:deployment_plan) do
        instance_double('Bosh::Director::DeploymentPlan::Planner',
          errand_instance_groups: [errand_instance_group, ignored_errand_instance_group],
                ip_provider: ip_provider
        )
      end

      let(:obsolete_instance_plans) { [ instance_double('Bosh::Director::DeploymentPlan::InstancePlan')]}
      let(:instance_deleter) { instance_double('Bosh::Director::InstanceDeleter') }

      before do
        allow(InstanceDeleter).to receive(:new).and_return(instance_deleter)
        allow(instance_deleter).to receive(:delete_instance_plans)
        allow(errand_instance).to receive(:update_variable_set)
        allow(errand_instance_group).to receive(:obsolete_instance_plans).and_return([])
        allow(ignored_errand_instance_group).to receive(:obsolete_instance_plans).and_return([])
      end

      describe '#perform' do
        it 'updates variable sets of errand instance groups' do
          expect(errand_instance).to receive(:update_variable_set)
          expect(ignored_errand_instance).to_not receive(:update_variable_set)
          subject.perform
        end

        context 'when instance plans require deletion' do
          before do
            allow(errand_instance_group).to receive(:obsolete_instance_plans).and_return(obsolete_instance_plans)
          end

          it 'deletes unneeded instances in errand instance groups' do
            expect(instance_deleter).to receive(:delete_instance_plans) do |instance_plans, _, _|
              expect(instance_plans).to eq(obsolete_instance_plans)
            end
            subject.perform
          end

          it 'logs delete event information' do
            expect(event_log).to receive(:begin_stage)
                                     .with('Deleting unneeded errand instances', 1)
                                     .and_return(event_log_stage)

            expect(logger).to receive(:info).with('Deleting no longer needed errand instances')
            expect(logger).to receive(:info).with('Deleted no longer needed errand instances')
            subject.perform
          end

        end

        context 'when instance plans do NOT require deletion' do
          it 'exits early and logs the lack of work needed' do
            expect(logger).to receive(:info).with('No unneeded errand instances to delete')
            expect(instance_deleter).to_not receive(:delete_instance_plans)
            subject.perform
          end
        end
      end
    end
  end
end
