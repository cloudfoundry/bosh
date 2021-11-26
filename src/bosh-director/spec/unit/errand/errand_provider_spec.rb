require 'spec_helper'

module Bosh::Director
  describe Errand::ErrandProvider do
    subject(:errand_provider) do
      Errand::ErrandProvider.new(logs_fetcher, instance_manager, event_manager, logger, task_result, deployment_planner_provider)
    end

    describe '#get' do
      let(:deployment_planner_provider) { instance_double(Errand::DeploymentPlannerProvider) }
      let(:deployment_planner) do
        instance_double(
          DeploymentPlan::Planner,
          availability_zones: [],
          template_blob_cache: template_blob_cache,
          ip_provider: ip_provider,
          use_short_dns_addresses?: false,
          use_link_dns_names?: false,
          link_provider_intents: [],
        )
      end
      let(:task_result) { instance_double(TaskDBWriter) }
      let(:instance_manager) { Api::InstanceManager.new }
      let(:logs_fetcher) { instance_double LogsFetcher }
      let(:event_manager) { instance_double(Bosh::Director::Api::EventManager) }
      let(:task_writer) { StringIO.new }
      let(:event_log) { EventLog::Log.new(task_writer) }
      let(:deployment_name) { deployment_model.name }
      let(:template_blob_cache) { instance_double(Bosh::Director::Core::Templates::TemplateBlobCache) }
      let(:runner) { instance_double(Errand::Runner) }
      let(:errand_step) { instance_double(Errand::LifecycleErrandStep) }
      let(:instance) do
        instance_double(
          DeploymentPlan::Instance,
          current_job_state: double(:current_job_state),
          uuid: instance_model.uuid,
          model: instance_model,
        )
      end
      let!(:instance_model) { Models::Instance.make(deployment: deployment_model, uuid: 'instance-uuid') }
      let(:ip_provider) { instance_double(DeploymentPlan::IpProvider) }
      let(:keep_alive) { false }
      let(:instance_slugs) { [] }
      let(:deployment_model) { Bosh::Director::Models::Deployment.make }

      before do
        allow(deployment_planner_provider).to receive(:get_by_name)
          .with(deployment_name, be_a(Array))
          .and_return(deployment_planner)
        allow(deployment_planner).to receive(:instance_groups).and_return(instance_groups)
        allow(Config).to receive(:event_log).and_return(event_log)
        allow(deployment_planner).to receive(:instance_group)
        allow(deployment_planner).to receive(:model).and_return(deployment_model)
      end

      context 'when running an errand by release job name' do
        let(:job_name) { 'errand-job-name' }
        let(:job) { instance_double(DeploymentPlan::Job, name: job_name) }
        let(:instance_group) do
          instance_double(DeploymentPlan::InstanceGroup, jobs: [job], instances: [instance], bind_instances: nil, errand?: false)
        end
        let(:instance_groups) { [instance_group] }

        it 'provides an errand that will run on the instance in that group' do
          expect(Errand::Runner).to receive(:new)
            .with(job_name, true, task_result, instance_manager, logs_fetcher)
            .and_return(runner)
          expect(Errand::LifecycleServiceStep).to receive(:new).with(
            runner, instance, logger
          ).and_return(errand_step)
          returned_errand = subject.get(deployment_name, 'errand-job-name', keep_alive, instance_slugs)
          expect(returned_errand.steps[0]).to eq(errand_step)
        end

        context 'when multiple instances within multiple instance groups have that job' do
          let(:job_state1) { double(:job_state1) }
          let(:job_state2) { double(:job_state2) }
          let(:job_state3) { double(:job_state3) }
          let(:needed_instance_plans) { [] }
          let(:service_group_name) { 'service-group-name' }
          let(:errand_group_name) { 'errand-group-name' }

          let(:instance1_model) { Models::Instance.make(deployment: deployment_model, job: service_group_name) }
          let(:instance1) do
            instance_double(
              DeploymentPlan::Instance,
              model: instance1_model,
              instance_group_name: instance1_model.job,
              uuid: instance1_model.uuid,
              index: 1,
              current_job_state: job_state1,
            )
          end

          let(:instance2_model) { Models::Instance.make(deployment: deployment_model, job: service_group_name) }
          let(:instance2) do
            instance_double(
              DeploymentPlan::Instance,
              model: instance2_model,
              instance_group_name: instance2_model.job,
              uuid: instance2_model.uuid,
              index: 2,
              current_job_state: job_state2,
            )
          end

          let(:instance3_model) { Models::Instance.make(deployment: deployment_model, job: errand_group_name) }
          let(:instance3) do
            instance_double(
              DeploymentPlan::Instance,
              model: instance3_model,
              instance_group_name: instance3_model.job,
              uuid: instance3_model.uuid,
              index: 3,
              current_job_state: job_state3,
            )
          end

          let(:instance_group1) do
            instance_double(
              DeploymentPlan::InstanceGroup,
              name: service_group_name,
              jobs: [job],
              bind_instances: nil,
              instances: [instance1, instance2],
              errand?: false,
            )
          end
          let(:instance_group2) do
            instance_double(
              DeploymentPlan::InstanceGroup,
              name: errand_group_name,
              jobs: [job],
              bind_instances: nil,
              instances: [instance3],
              errand?: true,
              needed_instance_plans: needed_instance_plans,
            )
          end
          let(:instance_groups) { [instance_group1, instance_group2] }
          let(:errand_step1) { instance_double(Errand::LifecycleServiceStep) }
          let(:errand_step2) { instance_double(Errand::LifecycleServiceStep) }
          let(:errand_step3) { instance_double(Errand::LifecycleErrandStep) }
          let(:package_compile_step) { instance_double(DeploymentPlan::Stages::PackageCompileStage) }

          before do
            allow(DeploymentPlan::Stages::PackageCompileStage).to receive(:create).and_return(package_compile_step)
            allow(package_compile_step).to receive(:perform)
            allow(instance_group2).to receive(:bind_instances)
            allow(Errand::Runner).to receive(:new).and_return(runner)
          end

          context 'when one instance has a matching non-errand job name' do
            let(:instance_groups) { [instance_group1, non_errand_ig] }
            let(:non_errand_job) { instance_double(DeploymentPlan::Job, name: 'errand-job-name', runs_as_errand?: false) }
            let(:non_errand_step) { instance_double(Errand::LifecycleServiceStep) }
            let(:non_errand_instance_model) { Models::Instance.make(deployment: deployment_model, job: errand_group_name) }
            let(:non_errand_instance) do
              instance_double(
                DeploymentPlan::Instance,
                model: non_errand_instance_model,
                instance_group_name: non_errand_instance_model.job,
                uuid: non_errand_instance_model.uuid,
                index: 2,
                current_job_state: 'running',
              )
            end
            let(:non_errand_ig) do
              instance_double(DeploymentPlan::InstanceGroup,
                              name: 'non_errand_ig',
                              jobs: [non_errand_job],
                              instances: [non_errand_instance],
                              errand?: false,
                              needed_instance_plans: [],
                              bind_instances: nil)
            end

            before do
              allow(deployment_planner).to receive(:instance_group).with(service_group_name).and_return(instance_group1)
              allow(deployment_planner).to receive(:instance_group).with('non_errand_ig').and_return(non_errand_ig)
            end

            it 'tries to run all matching jobs even if some are not errands ' do
              expect(Errand::LifecycleServiceStep).to receive(:new)
                .with(runner, instance1, logger)
                .and_return(errand_step1)
              expect(Errand::LifecycleServiceStep).to receive(:new)
                .with(runner, instance2, logger)
                .and_return(errand_step2)
              expect(Errand::LifecycleServiceStep).to receive(:new)
                .with(runner, non_errand_instance, logger)
                .and_return(non_errand_step)

              returned_errands = subject.get(deployment_name, 'errand-job-name', keep_alive, instance_slugs)
              expect(returned_errands.steps).to contain_exactly(errand_step1, errand_step2, non_errand_step)
            end
          end

          context 'when a matching instance group has 0 instances' do
            let(:instance_group2) do
              instance_double(
                DeploymentPlan::InstanceGroup,
                name: errand_group_name,
                jobs: [job],
                bind_instances: nil,
                instances: [],
                errand?: true,
                needed_instance_plans: needed_instance_plans,
              )
            end

            context 'when using an instance filter' do
              let(:instance_slugs) { [{ 'group' => 'service-group-name' }] }

              it 'no-ops successfully on that instance group and continues' do
                expect(Errand::Runner).to receive(:new)
                  .with(job_name, true, task_result, instance_manager, logs_fetcher)
                  .and_return(runner)

                expect(Errand::LifecycleServiceStep).to receive(:new)
                  .with(runner, instance1, logger)
                  .and_return(errand_step1)
                expect(Errand::LifecycleServiceStep).to receive(:new)
                  .with(runner, instance2, logger)
                  .and_return(errand_step2)

                returned_errands = subject.get(deployment_name, 'errand-job-name', keep_alive, instance_slugs)
                expect(returned_errands.steps).to contain_exactly(errand_step1, errand_step2)
              end
            end

            context 'without any instance filter' do
              it 'no-ops successfully on that instance group and continues' do
                expect(Errand::Runner).to receive(:new)
                  .with(job_name, true, task_result, instance_manager, logs_fetcher)
                  .and_return(runner)

                expect(Errand::LifecycleServiceStep).to receive(:new)
                  .with(runner, instance1, logger)
                  .and_return(errand_step1)
                expect(Errand::LifecycleServiceStep).to receive(:new)
                  .with(runner, instance2, logger)
                  .and_return(errand_step2)

                returned_errands = subject.get(deployment_name, 'errand-job-name', keep_alive, instance_slugs)
                expect(returned_errands.steps).to contain_exactly(errand_step1, errand_step2)
              end
            end
          end

          context 'when running an errand where instance group name and the release job name are the same' do
            let(:ambiguous_errand_name) { 'ambiguous-errand-name' }
            let(:job_name) { ambiguous_errand_name }
            let(:service_group_name) { ambiguous_errand_name }

            before do
              allow(Errand::Runner).to receive(:new)
                .with(job_name, true, task_result, instance_manager, logs_fetcher)
                .and_return(runner)

              allow(Errand::LifecycleServiceStep).to receive(:new)
                .with(runner, instance1, logger)
                .and_return(errand_step1)
              allow(Errand::LifecycleServiceStep).to receive(:new)
                .with(runner, instance2, logger)
                .and_return(errand_step2)
              allow(Errand::LifecycleErrandStep).to receive(:new)
                .with(runner, deployment_planner, job_name, instance3, instance_group2, keep_alive, deployment_name, logger)
                .and_return(errand_step3)
              allow(deployment_planner).to receive(:instance_group)
                .with(ambiguous_errand_name)
                .and_return(instance_group2)
            end

            it 'treats the name as a job name and runs the errand on all instances that have the release job' do
              returned_errands = subject.get(deployment_name, ambiguous_errand_name, keep_alive, instance_slugs)
              expect(returned_errands.steps).to contain_exactly(errand_step1, errand_step2, errand_step3)
            end

            it 'prints a warning to the task output' do
              subject.get(deployment_name, ambiguous_errand_name, keep_alive, instance_slugs)

              output = task_writer.string
              lines = output.split("\n")

              line_0_json = JSON.parse(lines[0])
              expect(line_0_json['state']).to eq('started')
              expect(line_0_json['stage']).to eq('Preparing deployment')

              line_1_json = JSON.parse(lines[1])
              expect(line_1_json['type']).to eq('warning')
              expect(line_1_json['message']).to eq("Ambiguous request: the requested errand name 'ambiguous-errand-name' " \
                'matches both a job name and an errand instance group name. Executing errand on all relevant ' \
                "instances with job 'ambiguous-errand-name'.")

              line_2_json = JSON.parse(lines[2])
              expect(line_2_json['type']).to eq('warning')
              expect(line_2_json['message']).to eq('Executing errand on multiple instances in parallel. ' \
                'Use the `--instance` flag to run the errand on a single instance.')

              line_3_json = JSON.parse(lines[3])
              expect(line_3_json['state']).to eq('finished')
              expect(line_3_json['stage']).to eq('Preparing deployment')
            end
          end

          it 'runs the job on all instances' do
            expect(Errand::Runner).to receive(:new)
              .with(job_name, true, task_result, instance_manager, logs_fetcher)
              .and_return(runner)

            expect(Errand::LifecycleServiceStep).to receive(:new)
              .with(runner, instance1, logger)
              .and_return(errand_step1)
            expect(Errand::LifecycleServiceStep).to receive(:new)
              .with(runner, instance2, logger)
              .and_return(errand_step2)
            expect(Errand::LifecycleErrandStep).to receive(:new)
              .with(runner, deployment_planner, job_name, instance3, instance_group2, keep_alive, deployment_name, logger)
              .and_return(errand_step3)

            returned_errands = subject.get(deployment_name, 'errand-job-name', keep_alive, instance_slugs)
            expect(returned_errands.steps).to contain_exactly(errand_step1, errand_step2, errand_step3)
          end

          context 'when a matching instance has no vm reference' do
            let(:job_state2) { nil }

            it 'runs the jobs successfully on all remaining instances' do
              expect(Errand::Runner).to receive(:new)
                .with(job_name, true, task_result, instance_manager, logs_fetcher)
                .and_return(runner)
              expect(Errand::LifecycleServiceStep).to receive(:new)
                .with(runner, instance1, logger)
                .and_return(errand_step1)
              expect(Errand::LifecycleServiceStep).not_to receive(:new)
                .with(runner, instance2, logger)
              expect(Errand::LifecycleErrandStep).to receive(:new)
                .with(runner, deployment_planner, job_name, instance3, instance_group2, keep_alive, deployment_name, logger)
                .and_return(errand_step3)

              returned_errands = subject.get(deployment_name, 'errand-job-name', keep_alive, instance_slugs)
              expect(returned_errands.steps).to contain_exactly(errand_step1, errand_step3)
            end

            it 'writes to the event log that a vm2 was missing' do
              subject.get(deployment_name, 'errand-job-name', keep_alive, instance_slugs)
              output = task_writer.string
              lines = output.split("\n")

              line_0_json = JSON.parse(lines[0])
              expect(line_0_json['state']).to eq('started')
              expect(line_0_json['stage']).to eq('Preparing deployment')

              line_1_json = JSON.parse(lines[1])
              expect(line_1_json['type']).to eq('warning')
              expect(line_1_json['message']).to include('Executing errand on multiple instances in parallel')

              line_2_json = JSON.parse(lines[2])
              expect(line_2_json['message']).to eq("Skipping instance: #{instance2} " \
                                                   'no matching VM reference was found')
              expect(line_2_json['type']).to eq('warning')
            end
          end

          it 'writes to the event log' do
            subject.get(deployment_name, 'errand-job-name', keep_alive, instance_slugs)
            output = task_writer.string
            lines = output.split("\n")

            line_0_json = JSON.parse(lines[0])
            expect(line_0_json['state']).to eq('started')
            expect(line_0_json['stage']).to eq('Preparing deployment')

            line_1_json = JSON.parse(lines[1])
            expect(line_1_json['type']).to eq('warning')
            expect(line_1_json['message']).to include('Executing errand on multiple instances in parallel')

            line_2_json = JSON.parse(lines[2])
            expect(line_2_json['state']).to eq('finished')
            expect(line_2_json['stage']).to eq('Preparing deployment')
          end

          context 'when selecting an instance from a service group' do
            let(:instance_slugs) { [{ 'group' => 'service-group-name', 'id' => instance2_model.uuid }] }

            it 'only creates an errand for the requested slug' do
              expect(Errand::LifecycleServiceStep).to receive(:new).with(
                runner, instance2, logger
              ).and_return(errand_step2)
              returned_errands = subject.get(deployment_name, 'errand-job-name', keep_alive, instance_slugs)
              expect(returned_errands.steps).to contain_exactly(errand_step2)
            end
          end

          context 'when selecting an instance from a errand group' do
            let(:instance_slugs) { [{ 'group' => 'errand-group-name' }] }
            it 'only creates an errand for the requested slug' do
              expect(Errand::LifecycleErrandStep).to receive(:new).with(
                runner, deployment_planner, job_name, instance3, instance_group2, keep_alive, deployment_name, logger
              ).and_return(errand_step3)
              returned_errands = subject.get(deployment_name, 'errand-job-name', keep_alive, instance_slugs)
              expect(returned_errands.steps).to contain_exactly(errand_step3)
            end
          end

          context 'when selecting an instance that does not exist' do
            let(:instance_slugs) { [{ 'group' => 'bogus-group-name', 'id' => '0' }] }
            it 'only creates an errand for the requested slug' do
              expect do
                subject.get(deployment_name, 'errand-job-name', keep_alive, instance_slugs)
              end.to raise_error('No instances match selection criteria: [{"group"=>"bogus-group-name", "id"=>"0"}]')
            end
          end
        end
      end

      context 'when running an errand by instance group name' do
        let(:ig_name) { 'instance-group-name' }
        let(:instance_groups) { [instance_group] }
        let(:non_errand_job) { instance_double(DeploymentPlan::Job, name: 'non-errand-job') }
        let(:errand_job_name) { 'errand-job' }
        let(:errand_job) { instance_double(DeploymentPlan::Job, name: errand_job_name) }
        let(:needed_instance_plans) { [] }
        let(:package_compile_step) { instance_double(DeploymentPlan::Stages::PackageCompileStage) }

        before do
          allow(deployment_planner).to receive(:instance_group).with(ig_name).and_return(instance_group)
        end

        context 'when there is a lifecycle: errand instance group with that name' do
          let(:dns_encoder) { instance_double(DnsEncoder) }
          let(:instance_group) do
            instance_double(DeploymentPlan::InstanceGroup,
                            name: ig_name,
                            jobs: [errand_job, non_errand_job],
                            instances: [instance],
                            errand?: true,
                            needed_instance_plans: needed_instance_plans,
                            bind_instances: nil)
          end

          before do
            allow(LocalDnsEncoderManager).to receive(:new_encoder_with_updated_index).and_return(dns_encoder)
            allow(instance).to receive(:model).and_return(instance_model)
            allow(DeploymentPlan::Stages::PackageCompileStage).to receive(:create).and_return(package_compile_step)
            allow(instance_group).to receive(:bind_instances)
            allow(package_compile_step).to receive(:perform)
          end

          it 'returns an errand object that will run on the first instance in that instance group' do
            expect(package_compile_step).to receive(:perform)
            expect(instance_group).to receive(:bind_instances).with(ip_provider)
            expect(JobRenderer).to receive(:render_job_instances_with_cache).with(
              logger,
              needed_instance_plans,
              template_blob_cache,
              an_instance_of(DnsEncoder),
              deployment_planner.link_provider_intents,
            )
            expect(Errand::Runner).to receive(:new)
              .with(ig_name, false, task_result, instance_manager, logs_fetcher)
              .and_return(runner)
            expect(Errand::LifecycleErrandStep).to receive(:new)
              .with(runner, deployment_planner, ig_name, instance, instance_group, keep_alive, deployment_name, logger)
              .and_return(errand_step)
            returned_errand = subject.get(deployment_name, ig_name, keep_alive, instance_slugs)
            expect(returned_errand.steps[0]).to eq(errand_step)
          end

          context 'and the lifecycle errand instance group name is the same as the job name' do
            let(:ig_name) { 'ig-name-matching-job-name' }
            let(:errand_job_name) { ig_name }

            it 'returns an errand object that will run on the first instance in that instance group' do
              expect(package_compile_step).to receive(:perform)
              expect(instance_group).to receive(:bind_instances).with(ip_provider)
              expect(JobRenderer).to receive(:render_job_instances_with_cache).with(
                logger,
                needed_instance_plans,
                template_blob_cache,
                an_instance_of(DnsEncoder),
                deployment_planner.link_provider_intents,
              )
              expect(Errand::Runner).to receive(:new)
                .with(ig_name, true, task_result, instance_manager, logs_fetcher)
                .and_return(runner)
              expect(Errand::LifecycleErrandStep).to receive(:new)
                .with(runner, deployment_planner, ig_name, instance, instance_group, keep_alive, deployment_name, logger)
                .and_return(errand_step)
              returned_errand = subject.get(deployment_name, ig_name, keep_alive, instance_slugs)
              expect(returned_errand.steps[0]).to eq(errand_step)
            end

            it 'should NOT be a deploy action' do
              expect(deployment_model.links_serial_id).to eq(0)

              subject.get(deployment_name, ig_name, keep_alive, instance_slugs)

              deployment_model.refresh
              expect(deployment_model.links_serial_id).to eq(0)
            end
          end

          context 'and it has stale errand links' do
            before do
              deployment_model.has_stale_errand_links = true
              deployment_model.save
            end

            it 'still treats it as a deploy action to resolve links' do
              expect(deployment_model.links_serial_id).to eq(0)

              subject.get(deployment_name, ig_name, keep_alive, instance_slugs)

              deployment_model.refresh
              expect(deployment_model.links_serial_id).to eq(1)
            end
          end

          context 'and instances are specified' do
            let(:instance_slugs) { ['group_name/0'] }
            it 'raises' do
              expect do
                subject.get(deployment_name, ig_name, keep_alive, instance_slugs)
              end.to raise_error(
                RunErrandError,
                'Filtering by instances is not supported when running errand by instance group name',
              )
            end
          end
        end

        context 'when there is a lifecycle: errand instance group with that name that has no instances' do
          let(:instance_group) do
            instance_double(DeploymentPlan::InstanceGroup,
                            name: ig_name,
                            jobs: [errand_job, non_errand_job],
                            instances: [],
                            errand?: true,
                            needed_instance_plans: needed_instance_plans,
                            bind_instances: nil)
          end

          it 'returns an errand object that will run on the first instance in that instance group' do
            expect do
              subject.get(deployment_name, ig_name, keep_alive, instance_slugs)
            end.to raise_error(InstanceNotFound, "Instance '#{deployment_name}/instance-group-name/0' doesn't exist")
          end
        end

        context 'when there is a lifecycle: errand and instance is stopped' do
          let(:instance_group) do
            instance_double(DeploymentPlan::InstanceGroup,
                            name: ig_name,
                            jobs: [errand_job, non_errand_job],
                            instances: [],
                            errand?: true,
                            needed_instance_plans: needed_instance_plans,
                            bind_instances: nil)
          end

          let!(:instance_model) { Models::Instance.make(deployment: deployment_model, uuid: 'instance-uuid', state: 'stopped') }

          it 'returns an error that instance is stopped' do
            expect do
              subject.get(deployment_name, ig_name, keep_alive, instance_slugs)
            end.to raise_error(RunErrandError,
                               "Instance(s) '#{instance_model.job}/instance-uuid' is stopped, " \
                               'unable to run errand. Maybe start vm?')
          end
        end

        context 'when there is not a lifecycle: errand instance group with that name' do
          let(:instance_group) do
            instance_double(
              DeploymentPlan::InstanceGroup,
              name: ig_name,
              jobs: [errand_job, non_errand_job],
              instances: [instance],
              errand?: false,
              needed_instance_plans: needed_instance_plans,
              bind_instances: nil,
            )
          end

          it 'fails' do
            expect do
              subject.get(deployment_name, ig_name, keep_alive, instance_slugs)
            end.to raise_error(
              RunErrandError,
              "Instance group 'instance-group-name' is not an errand. " \
              "To mark an instance group as an errand set its lifecycle to 'errand' in the deployment manifest.",
            )
          end
        end

        context 'when there is not a lifecycle: errand instance group with that name' do
          let(:instance_group) { nil }
          let(:instance_groups) { [] }

          it 'fails' do
            expect do
              subject.get(deployment_name, ig_name, keep_alive, instance_slugs)
            end.to raise_error(JobNotFound, "Errand 'instance-group-name' doesn't exist")
          end
        end
      end
    end
  end
end
