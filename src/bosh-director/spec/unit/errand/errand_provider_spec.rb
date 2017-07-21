require 'spec_helper'

module Bosh::Director
  describe Errand::ErrandProvider do
    subject(:errand_provider) do
      Errand::ErrandProvider.new(logs_fetcher, instance_manager, event_manager, logger, task_result, deployment_planner_provider)
    end

    describe '#get' do
      let(:deployment_planner) { instance_double(DeploymentPlan::Planner, job_renderer: job_renderer, ip_provider: ip_provider) }
      let(:deployment_planner_provider) { instance_double(Errand::DeploymentPlannerProvider) }
      let(:task_result) { instance_double(TaskDBWriter) }
      let(:instance_manager) { instance_double(Api::InstanceManager) }
      let(:logs_fetcher) { instance_double (LogsFetcher) }
      let(:event_manager) { instance_double(Bosh::Director::Api::EventManager) }
      let(:task_writer) { TaskDBWriter.new(:event_output, task.id) }
      let(:task) { Models::Task.make(:id => 42, :username => 'user') }
      let(:event_log) { EventLog::Log.new(task_writer) }
      let(:deployment_name) { 'fake-dep-name' }
      let(:job_renderer) { JobRenderer.create }
      let(:runner) { instance_double(Errand::Runner) }
      let(:errand_step) { instance_double(Errand::ErrandStep) }
      let(:instance) { instance_double(DeploymentPlan::Instance) }
      let(:ip_provider) { instance_double(DeploymentPlan::IpProvider) }
      let(:when_changed) { false }
      let(:keep_alive) { false }

      before do
        allow(deployment_planner_provider).to receive(:get_by_name).with(deployment_name).and_return(deployment_planner)
        allow(deployment_planner).to receive(:instance_groups).and_return(instance_groups)
        allow(Config).to receive(:event_log).and_return(event_log)
      end

      context 'when running an errand by release job name' do
        let(:job_name) { 'errand-job-name' }
        let(:job) { instance_double(DeploymentPlan::Job, name: job_name, runs_as_errand?: true) }
        let(:instance_group) { instance_double(DeploymentPlan::InstanceGroup, jobs: [job], instances: [instance], is_errand?: false) }
        let(:instance_groups) { [instance_group] }

        it 'provides an errand that will run on the first instance in that group' do
          expect(Errand::Runner).to receive(:new).with(job_name, true, task_result, instance_manager, logs_fetcher).and_return(runner)
          expect(Errand::ErrandStep).to receive(:new).with(
            runner, deployment_planner, job_name, instance, instance_group, false, keep_alive, deployment_name, logger
          ).and_return(errand_step)
          returned_errand = subject.get(deployment_name, 'errand-job-name', when_changed, keep_alive)
          expect(returned_errand.steps[0]).to eq(errand_step)

        end
      end

      context 'when running an errand by instance group name' do
        let(:instance_group_name) { 'instance-group-name' }
        let(:instance_groups) { [instance_group] }
        let(:non_errand_job) { instance_double(DeploymentPlan::Job, name: 'non-errand-job', runs_as_errand?: false) }
        let(:errand_job_name) {'errand-job'}
        let(:errand_job) { instance_double(DeploymentPlan::Job, name: errand_job_name, runs_as_errand?: true) }
        let(:needed_instance_plans) { [] }
        let(:instance_model) { Models::Instance.make }
        let(:package_compile_step) { instance_double(DeploymentPlan::Steps::PackageCompileStep) }

        before do
          allow(deployment_planner).to receive(:instance_group).with(instance_group_name).and_return(instance_group)
        end

        context 'when there is a lifecycle: errand instance group with that name' do
          let(:instance_group) do
            instance_double(DeploymentPlan::InstanceGroup,
              name: instance_group_name,
              jobs: [errand_job, non_errand_job],
              instances: [instance],
              is_errand?: true,
              needed_instance_plans: needed_instance_plans,
            )
          end

          before do
            allow(instance).to receive(:model).and_return(instance_model)
            allow(DeploymentPlan::Steps::PackageCompileStep).to receive(:create).and_return(package_compile_step)
          end

          it 'returns an errand object that will run on the first instance in that instance group' do
            expect(package_compile_step).to receive(:perform)
            expect(instance_group).to receive(:bind_instances).with(ip_provider)
            expect(job_renderer).to receive(:render_job_instances).with(needed_instance_plans)
            expect(Errand::Runner).to receive(:new).with(instance_group_name, false, task_result, instance_manager, logs_fetcher).and_return(runner)
            expect(Errand::ErrandStep).to receive(:new).with(
              runner, deployment_planner, instance_group_name, instance, instance_group, false, keep_alive, deployment_name, logger
            ).and_return(errand_step)
            returned_errand = subject.get(deployment_name, instance_group_name, when_changed, keep_alive)
            expect(returned_errand.steps[0]).to eq(errand_step)
          end

          context 'and the lifecycle errand instance group name is the same as the job name' do
            let(:instance_group_name) { 'ig-name-matching-job-name' }
            let(:errand_job_name) { instance_group_name }

            it 'returns an errand object that will run on the first instance in that instance group' do
              expect(package_compile_step).to receive(:perform)
              expect(instance_group).to receive(:bind_instances).with(ip_provider)
              expect(job_renderer).to receive(:render_job_instances).with(needed_instance_plans)
              expect(Errand::Runner).to receive(:new).with(instance_group_name, true, task_result, instance_manager, logs_fetcher).and_return(runner)
              expect(Errand::ErrandStep).to receive(:new).with(
                runner, deployment_planner, instance_group_name, instance, instance_group, false, keep_alive, deployment_name, logger
              ).and_return(errand_step)
              returned_errand = subject.get(deployment_name, instance_group_name, when_changed, keep_alive)
              expect(returned_errand.steps[0]).to eq(errand_step)
            end
          end
        end

        context 'when there is a lifecycle: errand instance group with that name that has no instances' do
          let(:instance_group) do
            instance_double(DeploymentPlan::InstanceGroup,
              name: instance_group_name,
              jobs: [errand_job, non_errand_job],
              instances: [],
              is_errand?: true,
              needed_instance_plans: needed_instance_plans,
            )
          end

          it 'returns an errand object that will run on the first instance in that instance group' do
            expect {
              subject.get(deployment_name, instance_group_name, when_changed, keep_alive)
            }.to raise_error(InstanceNotFound, "Instance 'fake-dep-name/instance-group-name/0' doesn't exist")
          end
        end

        context 'when there is not a lifecycle: errand instance group with that name' do
          let(:instance_group) do
            instance_double(DeploymentPlan::InstanceGroup,
              name: instance_group_name,
              jobs: [errand_job, non_errand_job],
              instances: [instance],
              is_errand?: false,
              needed_instance_plans: needed_instance_plans,
            )
          end

          it 'fails' do
            expect {
              subject.get(deployment_name, instance_group_name, when_changed, keep_alive)
            }.to raise_error(RunErrandError, "Instance group 'instance-group-name' is not an errand. To mark an instance group as an errand set its lifecycle to 'errand' in the deployment manifest.")
          end
        end

        context 'when there is not a lifecycle: errand instance group with that name' do
          let(:instance_group) { nil }
          let(:instance_groups) { [] }

          it 'fails' do
            expect {
              subject.get(deployment_name, instance_group_name, when_changed, keep_alive)
            }.to raise_error(JobNotFound, "Errand 'instance-group-name' doesn't exist")
          end
        end
      end
    end
  end
end

