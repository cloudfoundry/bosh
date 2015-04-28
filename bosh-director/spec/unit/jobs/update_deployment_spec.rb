require 'spec_helper'

module Bosh::Director::Jobs
  describe UpdateDeployment do
    subject(:job) { UpdateDeployment.new(manifest_path, cloud_config_id) }

    let(:config) { Bosh::Director::Config.load_file(asset('test-director-config.yml'))}
    let(:directory) { Support::FileHelpers::DeploymentDirectory.new }
    let(:manifest_path) { directory.add_file('deployment.yml', manifest_content) }
    let(:manifest_content) { Psych.dump ManifestHelper.default_legacy_manifest }
    let(:cloud_config_id) { nil }

    before do
      allow(Bosh::Director::Config).to receive(:cloud) { instance_double(Bosh::Cloud) }
      Bosh::Director::App.new(config)
    end

    describe '#perform' do
      let(:compile_step) { instance_double('Bosh::Director::DeploymentPlan::Steps::PackageCompileStep') }
      let(:update_step) { instance_double('Bosh::Director::DeploymentPlan::Steps::UpdateStep') }
      let(:notifier) { instance_double('Bosh::Director::DeploymentPlan::Notifier') }

      before do
        allow(Bosh::Director::DeploymentPlan::Steps::PackageCompileStep).to receive(:new)
            .and_return(compile_step)
        allow(Bosh::Director::DeploymentPlan::Steps::UpdateStep).to receive(:new)
            .and_return(update_step)
        allow(Bosh::Director::DeploymentPlan::Notifier).to receive(:new)
            .and_return(notifier)
      end

      context 'when all steps complete' do
        before do
          allow(Bosh::Director::DeploymentPlan::PlannerFactory).to receive(:new).
              and_return(planner_factory)
        end
        let(:planner_factory) do
          instance_double(
            'Bosh::Director::DeploymentPlan::PlannerFactory',
            planner: planner,
          )
        end
        let(:planner) do
          instance_double('Bosh::Director::DeploymentPlan::Planner', name: 'deployment-name', resource_pools: [])
        end

        before do
          expect(job).to receive(:with_deployment_lock).and_yield.ordered
          expect(notifier).to receive(:send_start_event).ordered
          expect(planner_factory).to receive(:planner).and_return(planner).ordered
          expect(update_step).to receive(:perform).ordered
          expect(notifier).to receive(:send_end_event).ordered
        end

        context 'when a cloud_config is passed in' do
          let(:cloud_config_id) { Bosh::Director::Models::CloudConfig.make.id }
          it 'uses the cloud config' do
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
