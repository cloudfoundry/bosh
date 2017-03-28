require 'spec_helper'
require 'bosh/director/deployment_plan/multi_job_updater'
require 'bosh/director/job_updater'

module Bosh::Director
  describe DeploymentPlan::Steps::UpdateStep do
    subject { DeploymentPlan::Steps::UpdateStep.new(base_job, deployment_plan, multi_job_updater) }
    let(:base_job) { Jobs::BaseJob.new }
    let(:event_log) { Bosh::Director::Config.event_log }
    let(:ip_provider) {instance_double('Bosh::Director::DeploymentPlan::IpProvider')}
    let(:skip_drain) {instance_double('Bosh::Director::DeploymentPlan::SkipDrain')}
    let(:errand_instance) { instance_double('Bosh::Director::DeploymentPlan::Instance') }
    let(:errand_instance_plan) {  instance_double('Bosh::Director::DeploymentPlan::InstancePlan', instance: errand_instance)  }
    let(:errand_instance_group) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', unignored_instance_plans: [errand_instance_plan]) }

    let(:deployment_plan) do
      instance_double('Bosh::Director::DeploymentPlan::Planner',
        update_stemcell_references!: nil,
        persist_updates!: nil,
        instance_groups_starting_on_deploy: [],
        instance_plans_with_missing_vms: [],
        errand_instance_groups: [errand_instance_group],
        ip_provider: ip_provider,
        job_renderer: JobRenderer.create,
        skip_drain: skip_drain,
        recreate: false,
        tags: {}
      )
    end

    let(:cloud) { Config.cloud }
    let(:manifest) { ManifestHelper.default_legacy_manifest }
    let(:releases) { [] }
    let(:multi_job_updater) { instance_double('Bosh::Director::DeploymentPlan::SerialMultiJobUpdater', run: nil) }
    let(:task) {Bosh::Director::Models::Task.make(:id => 42, :username => 'user')}
    before do
      allow(base_job).to receive(:logger).and_return(logger)
      allow(base_job).to receive(:track_and_log).and_yield
      allow(Bosh::Director::Config).to receive(:dns_enabled?).and_return(true)
      allow(base_job).to receive(:task_id).and_return(task.id)
      allow(Bosh::Director::Config).to receive(:current_job).and_return(base_job)
      allow(Bosh::Director::Config).to receive(:record_events).and_return(true)
      fake_app
    end

    describe '#perform' do
      let(:job1) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', instances: [instance1, instance2]) }
      let(:job2) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', instances: [instance3]) }
      let(:instance1) { instance_double('Bosh::Director::DeploymentPlan::Instance') }
      let(:instance2) { instance_double('Bosh::Director::DeploymentPlan::Instance') }
      let(:instance3) { instance_double('Bosh::Director::DeploymentPlan::Instance') }

      before do
        allow(deployment_plan).to receive(:unneeded_instance_plans).and_return([])
      end

      def it_deletes_unneeded_instances
        existing_instance = Models::Instance.make
        existing_instance_plan = instance_double(DeploymentPlan::InstancePlan, existing_instance: existing_instance)
        allow(deployment_plan).to receive(:unneeded_instance_plans).and_return([existing_instance_plan])

        event_log_stage = instance_double('Bosh::Director::EventLog::Stage')
        expect(Config.event_log).to receive(:begin_stage)
                               .with('Deleting unneeded instances', 1)
                               .and_return(event_log_stage)

        instance_deleter = instance_double('Bosh::Director::InstanceDeleter')
        expect(InstanceDeleter).to receive(:new)
                                     .and_return(instance_deleter)

        expect(instance_deleter).to receive(:delete_instance_plans) do |instance_plans, event_log, _|
          expect(instance_plans.map(&:existing_instance)).to eq([existing_instance])
        end
      end

      it 'runs deployment plan update stages in the correct order' do
        event_log_stage = instance_double('Bosh::Director::EventLog::Stage')
        allow(event_log_stage).to receive(:advance_and_track).and_yield
        allow(deployment_plan).to receive(:instance_groups_starting_on_deploy).with(no_args).and_return([job1, job2])

        it_deletes_unneeded_instances.ordered
        expect(base_job).to receive(:task_checkpoint).with(no_args).ordered
        expect(multi_job_updater).to receive(:run).with(base_job, ip_provider, [job1, job2]).ordered
        expect(errand_instance).to receive(:update_variable_set).ordered
        expect(deployment_plan).to receive(:persist_updates!).ordered
        subject.perform
      end

      context 'when perform fails' do
        let(:some_error) { RuntimeError.new('oops') }

        before do
          existing_vm = Models::Vm.make(cid: 'vm_cid')
          existing_instance = Models::Instance.make
          existing_instance.add_vm existing_vm
          existing_instance.update(active_vm: existing_vm)
          existing_instance_plan = instance_double(DeploymentPlan::InstancePlan, existing_instance: existing_instance, new?: false, needs_to_fix?: true)
          allow(deployment_plan).to receive(:unneeded_instance_plans).and_return([existing_instance_plan])

          agent_client = instance_double(AgentClient, drain: 0, stop: nil)
          allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).and_return(agent_client)
          expect(cloud).to receive(:delete_vm).with('vm_cid').and_raise(some_error)
        end

        it 'still updates the stemcell references' do
          expect(deployment_plan).to receive(:update_stemcell_references!)

          expect{
            subject.perform
          }.to raise_error(some_error)
        end
      end
    end
  end
end
