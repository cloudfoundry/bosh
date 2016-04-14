require 'spec_helper'

module Bosh::Director::Jobs
  describe UpdateDeployment do
    subject(:job) { UpdateDeployment.new(manifest_path, cloud_config_id, runtime_config_id) }

    let(:config) { Bosh::Director::Config.load_file(asset('test-director-config.yml'))}
    let(:directory) { Support::FileHelpers::DeploymentDirectory.new }
    let(:manifest_path) { directory.add_file('deployment.yml', manifest_content) }
    let(:manifest_content) { Psych.dump ManifestHelper.default_legacy_manifest }
    let(:cloud_config_id) { nil }
    let(:runtime_config_id) { nil }
    let(:deployment_job) { Bosh::Director::DeploymentPlan::Job.new(logger) }
    let(:task) {Bosh::Director::Models::Task.make(:id => 42, :username => 'user')}

    before do
      allow(Bosh::Director::Config).to receive(:cloud) { instance_double(Bosh::Cloud) }
      Bosh::Director::App.new(config)
      allow(job).to receive(:task_id).and_return(task.id)
      allow(Time).to receive_messages(now: Time.parse('2016-02-15T09:55:40Z'))
    end

    describe '#perform' do
      let(:compile_step) { instance_double('Bosh::Director::DeploymentPlan::Steps::PackageCompileStep') }
      let(:update_step) { instance_double('Bosh::Director::DeploymentPlan::Steps::UpdateStep') }
      let(:notifier) { instance_double('Bosh::Director::DeploymentPlan::Notifier') }
      let(:job_renderer) { instance_double('Bosh::Director::JobRenderer') }

      before do
        allow(Bosh::Director::DeploymentPlan::Steps::PackageCompileStep).to receive(:new).and_return(compile_step)
        allow(Bosh::Director::DeploymentPlan::Steps::UpdateStep).to receive(:new).and_return(update_step)
        allow(Bosh::Director::DeploymentPlan::Notifier).to receive(:new).and_return(notifier)
        allow(Bosh::Director::JobRenderer).to receive(:create).and_return(job_renderer)
      end

      context 'when all steps complete' do
        before do
          allow(Bosh::Director::DeploymentPlan::PlannerFactory).to receive(:new).
              and_return(planner_factory)
        end
        let(:planner_factory) do
          instance_double(
            'Bosh::Director::DeploymentPlan::PlannerFactory',
            create_from_manifest: planner,
          )
        end
        let(:planner) do
          instance_double('Bosh::Director::DeploymentPlan::Planner', name: 'deployment-name', jobs_starting_on_deploy: [deployment_job])
        end

        before do
          expect(job).to receive(:with_deployment_lock).and_yield.ordered
          expect(notifier).to receive(:send_start_event).ordered
          expect(update_step).to receive(:perform).ordered
          expect(notifier).to receive(:send_end_event).ordered
          allow(job_renderer).to receive(:render_job_instances)
          allow(planner).to receive(:bind_models)
          allow(planner).to receive(:validate_packages)
          allow(planner).to receive(:compile_packages)
          allow(planner).to receive(:jobs).and_return([deployment_job])
        end

        it 'binds models, renders templates, compiles packages, runs post-deploy scripts' do
          expect(planner).to receive(:bind_models)
          expect(job_renderer).to receive(:render_job_instances).with(deployment_job.needed_instance_plans)
          expect(planner).to receive(:compile_packages)
          expect(job).to_not receive(:run_post_deploys)

          job.perform
        end

        context 'when a cloud_config is passed in' do
          let(:cloud_config_id) { Bosh::Director::Models::CloudConfig.make.id }
          it 'uses the cloud config' do
            expect(job.perform).to eq("/deployments/deployment-name")
          end
        end

        context 'when a runtime_config is passed in' do
          let(:runtime_config_id) { Bosh::Director::Models::RuntimeConfig.make.id }
          it 'uses the runtime config' do
            expect(job.perform).to eq("/deployments/deployment-name")
          end
        end

        it 'performs an update' do
          expect(job.perform).to eq("/deployments/deployment-name")
        end

        it 'cleans up the temporary manifest' do
          job.perform
          expect(File.exist? manifest_path).to be_falsey
        end

        context "when the deployment makes no changes to existing vms" do
          it 'will not run post-deploy scripts' do
            expect(job).to_not receive(:run_post_deploys)

            job.perform
          end
        end

        context "when the deployment makes changes to existing vms" do
          let (:instance_plan) { instance_double('Bosh::Director::DeploymentPlan::InstancePlan') }

          it 'will run post-deploy scripts' do
            allow(planner).to receive(:jobs).and_return([deployment_job])
            allow(deployment_job).to receive(:did_change).and_return(true)

            expect(Bosh::Director::PostDeploymentScriptRunner).to receive(:run_post_deploys_after_deployment)

            job.perform
          end
        end

        it 'should store new events' do
          expect {
            job.perform
          }.to change {
            Bosh::Director::Models::Event.count }.from(0).to(2)

          event_1 = Bosh::Director::Models::Event.first
          expect(event_1.user).to eq(task.username)
          expect(event_1.action).to eq('create')
          expect(event_1.object_type).to eq('deployment')
          expect(event_1.deployment).to eq('deployment-name')
          expect(event_1.object_name).to eq('deployment-name')
          expect(event_1.task).to eq("#{task.id}")
          expect(event_1.timestamp).to eq(Time.now)

          event_2 = Bosh::Director::Models::Event.order(:id).last
          expect(event_2.parent_id).to eq(1)
          expect(event_2.user).to eq(task.username)
          expect(event_2.action).to eq('create')
          expect(event_2.object_type).to eq('deployment')
          expect(event_2.deployment).to eq('deployment-name')
          expect(event_2.object_name).to eq('deployment-name')
          expect(event_2.task).to eq("#{task.id}")
          expect(event_2.timestamp).to eq(Time.now)
        end

        it 'should define `update` deployment action' do
          Bosh::Director::Models::Deployment.make(name: 'deployment-name')
          expect {
            job.perform
          }.to change {
            Bosh::Director::Models::Event.count }.from(0).to(2)

          event_1 = Bosh::Director::Models::Event.first
          expect(event_1.user).to eq('user')
          expect(event_1.action).to eq('update')
          expect(event_1.object_type).to eq('deployment')
          expect(event_1.deployment).to eq('deployment-name')
          expect(event_1.object_name).to eq('deployment-name')
          expect(event_1.task).to eq("42")
          expect(event_1.timestamp).to eq(Time.now)

          event_2 = Bosh::Director::Models::Event.order(:id).last
          expect(event_2.parent_id).to eq(1)
          expect(event_2.user).to eq('user')
          expect(event_2.action).to eq('update')
          expect(event_2.object_type).to eq('deployment')
          expect(event_2.deployment).to eq('deployment-name')
          expect(event_2.object_name).to eq('deployment-name')
          expect(event_2.task).to eq("42")
          expect(event_2.timestamp).to eq(Time.now)
        end
      end

      context 'when the first step fails' do
        before do
          expect(job).to receive(:with_deployment_lock).and_yield.ordered
          expect(notifier).to receive(:send_start_event).ordered
        end

        it 'does not compile or update' do
          expect {
            job.perform
          }.to raise_error(Exception)
        end

        it 'cleans up the temporary manifest' do
          expect {
            job.perform
          }.to raise_error(Exception)
          expect(File.exist? manifest_path).to be_falsey
        end
      end
    end
  end
end
