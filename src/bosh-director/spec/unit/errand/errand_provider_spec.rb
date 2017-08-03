require 'spec_helper'

module Bosh::Director
  describe Errand::ErrandProvider do
    subject(:errand_provider) do
      Errand::ErrandProvider.new(logs_fetcher, instance_manager, event_manager, logger, task_result, deployment_planner_provider)
    end

    describe '#get' do
      let(:deployment_planner_provider) { instance_double(Errand::DeploymentPlannerProvider) }
      let(:deployment_planner) { instance_double(DeploymentPlan::Planner, availability_zones: [], template_blob_cache: template_blob_cache, ip_provider: ip_provider) }
      let(:task_result) { instance_double(TaskDBWriter) }
      let(:instance_manager) { instance_double(Api::InstanceManager) }
      let(:logs_fetcher) { instance_double (LogsFetcher) }
      let(:event_manager) { instance_double(Bosh::Director::Api::EventManager) }
      let(:task_writer) { StringIO.new }
      let(:event_log) { EventLog::Log.new(task_writer) }
      let(:deployment_name) { 'fake-dep-name' }
      let(:template_blob_cache) { instance_double(Bosh::Director::Core::Templates::TemplateBlobCache) }
      let(:runner) { instance_double(Errand::Runner) }
      let(:errand_step) { instance_double(Errand::LifecycleErrandStep) }
      let(:instance) { instance_double(DeploymentPlan::Instance) }
      let(:ip_provider) { instance_double(DeploymentPlan::IpProvider) }
      let(:when_changed) { false }
      let(:keep_alive) { false }
      let(:instance_slugs) { [] }

      before do
        allow(deployment_planner_provider).to receive(:get_by_name).with(deployment_name).and_return(deployment_planner)
        allow(deployment_planner).to receive(:instance_groups).and_return(instance_groups)
        allow(Config).to receive(:event_log).and_return(event_log)
        allow(deployment_planner).to receive(:instance_group)
      end

      context 'when running an errand by release job name' do
        let(:job_name) { 'errand-job-name' }
        let(:job) { instance_double(DeploymentPlan::Job, name: job_name, runs_as_errand?: true) }
        let(:instance_group) { instance_double(DeploymentPlan::InstanceGroup, jobs: [job], instances: [instance], is_errand?: false) }
        let(:instance_groups) { [instance_group] }

        it 'provides an errand that will run on the instance in that group' do
          expect(Errand::Runner).to receive(:new).with(job_name, true, task_result, instance_manager, logs_fetcher).and_return(runner)
          expect(Errand::LifecycleServiceStep).to receive(:new).with(
            runner, job_name, instance, logger
          ).and_return(errand_step)
          returned_errand = subject.get(deployment_name, 'errand-job-name', when_changed, keep_alive, instance_slugs)
          expect(returned_errand.steps[0]).to eq(errand_step)
        end

        context 'when multiple instances within multiple instance groups have that job' do
          let(:needed_instance_plans) { [] }
          let(:service_group_name) { 'service-group-name' }
          let(:errand_group_name) { 'errand-group-name' }
          let(:instance1) { instance_double(DeploymentPlan::Instance, model: instance1_model, job_name: service_group_name, uuid: 'uuid-1', index: 1) }
          let(:instance1_model) { Models::Instance.make }
          let(:instance2) { instance_double(DeploymentPlan::Instance, model: instance2_model, job_name: service_group_name, uuid: 'uuid-2', index: 2) }
          let(:instance2_model) { Models::Instance.make }
          let(:instance3) { instance_double(DeploymentPlan::Instance, model: instance3_model, job_name: errand_group_name, uuid: 'uuid-3', index: 3) }
          let(:instance3_model) { Models::Instance.make }
          let(:instance_group1) { instance_double(DeploymentPlan::InstanceGroup, name: service_group_name, jobs: [job], instances: [instance1, instance2], is_errand?: false) }
          let(:instance_group2) { instance_double(DeploymentPlan::InstanceGroup, name: errand_group_name, jobs: [job], instances: [instance3], is_errand?: true, needed_instance_plans: needed_instance_plans) }
          let(:instance_groups) { [instance_group1, instance_group2] }
          let(:errand_step1) { instance_double(Errand::LifecycleServiceStep) }
          let(:errand_step2) { instance_double(Errand::LifecycleServiceStep) }
          let(:errand_step3) { instance_double(Errand::LifecycleErrandStep) }
          let(:package_compile_step) { instance_double(DeploymentPlan::Steps::PackageCompileStep) }

          before do
            allow(DeploymentPlan::Steps::PackageCompileStep).to receive(:create).and_return(package_compile_step)
            allow(package_compile_step).to receive(:perform)
            allow(instance_group2).to receive(:bind_instances)
            allow(Errand::Runner).to receive(:new).and_return(runner)
          end

          context 'when running an errand where instance group name and the release job name are the same' do
            let(:ambiguous_errand_name) { 'ambiguous-errand-name' }
            let(:job_name) { ambiguous_errand_name }
            let(:service_group_name) { ambiguous_errand_name }

            before do
              allow(Errand::Runner).to receive(:new).with(job_name, true, task_result, instance_manager, logs_fetcher).and_return(runner)
              allow(Errand::LifecycleServiceStep).to receive(:new).with(
                runner, job_name, instance1, logger
              ).and_return(errand_step1)
              allow(Errand::LifecycleServiceStep).to receive(:new).with(
                runner, job_name, instance2, logger
              ).and_return(errand_step2)
              allow(Errand::LifecycleErrandStep).to receive(:new).with(
                runner, deployment_planner, job_name, instance3, instance_group2, false, keep_alive, deployment_name, logger
              ).and_return(errand_step3)
              allow(deployment_planner).to receive(:instance_group).with(ambiguous_errand_name).and_return(instance_group2)
            end

            it 'treats the name as a job name and runs the errand on all instances that have the release job' do
              returned_errands = subject.get(deployment_name, ambiguous_errand_name, when_changed, keep_alive, instance_slugs)
              expect(returned_errands.steps).to contain_exactly(errand_step1, errand_step2, errand_step3)
            end

            it 'prints a warning to the task output' do
              subject.get(deployment_name, ambiguous_errand_name, when_changed, keep_alive, instance_slugs)

              output = task_writer.string
              lines = output.split("\n")

              line_0_json = JSON.parse(lines[0])
              expect(line_0_json['state']).to eq('started')
              expect(line_0_json['stage']).to eq('Preparing deployment')

              line_1_json = JSON.parse(lines[1])
              expect(line_1_json['type']).to eq('warning')
              expect(line_1_json['message']).to eq("Ambiguous request: the requested errand name 'ambiguous-errand-name' " +
                "matches both a job name and an errand instance group name. Executing errand on all relevant " +
                "instances with job 'ambiguous-errand-name'.")

              line_2_json = JSON.parse(lines[2])
              expect(line_2_json['state']).to eq('finished')
              expect(line_2_json['stage']).to eq('Preparing deployment')
            end
          end

          it 'runs the job on all instances' do
            expect(Errand::Runner).to receive(:new).with(job_name, true, task_result, instance_manager, logs_fetcher).and_return(runner)
            expect(Errand::LifecycleServiceStep).to receive(:new).with(
              runner, job_name, instance1, logger
            ).and_return(errand_step1)
            expect(Errand::LifecycleServiceStep).to receive(:new).with(
              runner, job_name, instance2, logger
            ).and_return(errand_step2)
            expect(Errand::LifecycleErrandStep).to receive(:new).with(
              runner, deployment_planner, job_name, instance3, instance_group2, false, keep_alive, deployment_name, logger
            ).and_return(errand_step3)

            returned_errands = subject.get(deployment_name, 'errand-job-name', when_changed, keep_alive, instance_slugs)
            expect(returned_errands.steps).to contain_exactly(errand_step1, errand_step2, errand_step3)
          end

          it 'writes to the event log' do
            subject.get(deployment_name, 'errand-job-name', when_changed, keep_alive, instance_slugs)
            output = task_writer.string
            lines = output.split("\n")

            line_0_json = JSON.parse(lines[0])
            expect(line_0_json['state']).to eq('started')
            expect(line_0_json['stage']).to eq('Preparing deployment')

            line_1_json = JSON.parse(lines[1])
            expect(line_1_json['state']).to eq('finished')
            expect(line_1_json['stage']).to eq('Preparing deployment')
          end

          context 'when selecting an instance from a service group' do
            let(:instance_slugs) { ['service-group-name/uuid-2'] }
            it 'only creates an errand for the requested slug' do
              expect(Errand::LifecycleServiceStep).to receive(:new).with(
                runner, job_name, instance2, logger
              ).and_return(errand_step2)
              returned_errands = subject.get(deployment_name, 'errand-job-name', when_changed, keep_alive, instance_slugs)
              expect(returned_errands.steps).to contain_exactly(errand_step2)
            end
          end

          context 'when selecting an instance from a errand group' do
            let(:instance_slugs) { ['errand-group-name'] }
            it 'only creates an errand for the requested slug' do
              expect(Errand::LifecycleErrandStep).to receive(:new).with(
                runner, deployment_planner, job_name, instance3, instance_group2, false, keep_alive, deployment_name, logger
              ).and_return(errand_step3)
              returned_errands = subject.get(deployment_name, 'errand-job-name', when_changed, keep_alive, instance_slugs)
              expect(returned_errands.steps).to contain_exactly(errand_step3)
            end
          end

          context 'when selecting an instance that does not exist' do
            let(:instance_slugs) { ['bogus-group-name/0'] }
            it 'only creates an errand for the requested slug' do
              expect{
                subject.get(deployment_name, 'errand-job-name', when_changed, keep_alive, instance_slugs)
              }.to raise_error('No instances match selection criteria: [bogus-group-name/0]')
            end
          end
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
          let(:dns_encoder) { DnsEncoder.new({}) }
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
            allow(LocalDnsEncoderManager).to receive(:new_encoder_with_updated_index).and_return(dns_encoder)
            allow(DeploymentPlan::Steps::PackageCompileStep).to receive(:create).and_return(package_compile_step)
            allow(instance_group).to receive(:bind_instances)
            allow(package_compile_step).to receive(:perform)
          end

          it 'returns an errand object that will run on the first instance in that instance group' do
            expect(package_compile_step).to receive(:perform)
            expect(instance_group).to receive(:bind_instances).with(ip_provider)
            expect(JobRenderer).to receive(:render_job_instances_with_cache).with(needed_instance_plans, template_blob_cache, dns_encoder, logger)
            expect(Errand::Runner).to receive(:new).with(instance_group_name, false, task_result, instance_manager, logs_fetcher).and_return(runner)
            expect(Errand::LifecycleErrandStep).to receive(:new).with(
              runner, deployment_planner, instance_group_name, instance, instance_group, false, keep_alive, deployment_name, logger
            ).and_return(errand_step)
            returned_errand = subject.get(deployment_name, instance_group_name, when_changed, keep_alive, instance_slugs)
            expect(returned_errand.steps[0]).to eq(errand_step)
          end

          context 'and the lifecycle errand instance group name is the same as the job name' do
            let(:instance_group_name) { 'ig-name-matching-job-name' }
            let(:errand_job_name) { instance_group_name }

            it 'returns an errand object that will run on the first instance in that instance group' do
              expect(package_compile_step).to receive(:perform)
              expect(instance_group).to receive(:bind_instances).with(ip_provider)
              expect(JobRenderer).to receive(:render_job_instances_with_cache).with(needed_instance_plans, template_blob_cache, dns_encoder, logger)
              expect(Errand::Runner).to receive(:new).with(instance_group_name, true, task_result, instance_manager, logs_fetcher).and_return(runner)
              expect(Errand::LifecycleErrandStep).to receive(:new).with(
                runner, deployment_planner, instance_group_name, instance, instance_group, false, keep_alive, deployment_name, logger
              ).and_return(errand_step)
              returned_errand = subject.get(deployment_name, instance_group_name, when_changed, keep_alive, instance_slugs)
              expect(returned_errand.steps[0]).to eq(errand_step)
            end
          end

          context 'and instances are specified' do
            let(:instance_slugs) { ['group_name/0'] }
            it 'raises' do
              expect {
                subject.get(deployment_name, instance_group_name, when_changed, keep_alive, instance_slugs)
              }.to raise_error(RunErrandError, 'Filtering by instances is not supported when running errand by instance group name')
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
              subject.get(deployment_name, instance_group_name, when_changed, keep_alive, instance_slugs)
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
              subject.get(deployment_name, instance_group_name, when_changed, keep_alive, instance_slugs)
            }.to raise_error(RunErrandError, "Instance group 'instance-group-name' is not an errand. To mark an instance group as an errand set its lifecycle to 'errand' in the deployment manifest.")
          end
        end

        context 'when there is not a lifecycle: errand instance group with that name' do
          let(:instance_group) { nil }
          let(:instance_groups) { [] }

          it 'fails' do
            expect {
              subject.get(deployment_name, instance_group_name, when_changed, keep_alive, instance_slugs)
            }.to raise_error(JobNotFound, "Errand 'instance-group-name' doesn't exist")
          end
        end
      end
    end
  end
end

