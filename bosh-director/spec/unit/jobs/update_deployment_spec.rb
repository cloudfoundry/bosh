require 'spec_helper'

module Bosh::Director::Jobs
  describe UpdateDeployment do
    subject(:job) { UpdateDeployment.new(manifest_path, cloud_config.id) }

    let(:config) { Bosh::Director::Config.load_file(asset('test-director-config.yml'))}
    let(:blobstores) { instance_double('Bosh::Director::Blobstores', blobstore: blobstore) }
    let(:blobstore) { instance_double('Bosh::Blobstore::Client') }
    let(:cloud_config) { Bosh::Director::Models::CloudConfig.create }

    let(:directory) { Support::FileHelpers::DeploymentDirectory.new }
    let(:cloud_config_id) { nil }
    let(:manifest_path) { directory.add_file('deployment.yml', manifest_content) }
    let(:manifest_content) do
      <<-MANIFEST
---
name: deployment-name
release:
  name: release-name
  version: 1
networks:
- name: network-name
  subnets: []
compilation:
  workers: 1
  network: network-name
  cloud_properties: {}
update:
  max_in_flight: 10
  canaries: 0
  canary_watch_time: 1000
  update_watch_time: 1000
resource_pools:
- name: my-pool
  cloud_properties: {}
  stemcell: {name: x, version: 1}
  network: network-name
      MANIFEST
    end

    before do
      Bosh::Director::App.new(config)
    end

    describe '#perform' do
      let(:prepare_step) { instance_double('Bosh::Director::DeploymentPlan::Preparer') }
      let(:compile_step) { instance_double('Bosh::Director::PackageCompiler') }
      let(:update_step) { instance_double('Bosh::Director::DeploymentPlan::Updater') }
      let(:notifier) { instance_double('Bosh::Director::DeploymentPlan::Notifier') }

      before do
        allow(Bosh::Director::DeploymentPlan::Preparer).to receive(:new)
            .and_return(prepare_step)
        allow(Bosh::Director::PackageCompiler).to receive(:new)
            .and_return(compile_step)
        allow(Bosh::Director::DeploymentPlan::Updater).to receive(:new)
            .and_return(update_step)
        allow(Bosh::Director::DeploymentPlan::Notifier).to receive(:new)
            .and_return(notifier)
      end

      describe "deployment_plan" do

        context "when the manifest is valid" do
          it "creates a plan from the proper manifest file" do
            plan = job.deployment_plan
            expect(plan.name).to eq("deployment-name")
          end
        end

        context "when the manifest is invalid" do
          let(:manifest_content) { strip_heredoc(<<-MANIFEST) }
            ---
            name: deployment-name
          MANIFEST

          it "creates a plan from the proper manifest file" do
            expect{ job.deployment_plan }.to raise_error(Bosh::Director::ValidationMissingField)
          end
        end

        context "when the cloud_config_id is not specified" do

        end

        context "when the cloud_config_id is specified", pending: 'awaiting new deployment plan contructor' do
          let(:manifest_content) do
            <<-MANIFEST
---
name: deployment-name
release:
  name: release-name
  version: 1
compilation:
  workers: 1
  network: other-network
  cloud_properties: {}
update:
  max_in_flight: 10
  canaries: 0
  canary_watch_time: 1000
  update_watch_time: 1000
            MANIFEST
          end

          let(:cloud_config_content) do
            <<-MANIFEST
---
networks:
- name: other-network
  subnets: []
resource_pools:
- name: my-pool
  cloud_properties: {}
  stemcell: {name: x, version: 1}
  network: other-network
            MANIFEST
          end

          let(:cloud_config_id) { cloud_config_record.id }
          let!(:cloud_config_record) { Bosh::Director::Models::CloudConfig.create(properties: cloud_config_content) }

          it "loads the config from the database" do
            expect(job.deployment_plan.resource_pools.map(&:name)).to eq(['my-pool'])
          end
        end
      end

      context 'without a cloud config' do
        context 'when all tasks complete' do
          before do
            expect(job).to receive(:with_deployment_lock).and_yield.ordered
            expect(notifier).to receive(:send_start_event).ordered
            expect(prepare_step).to receive(:prepare).ordered
            expect(compile_step).to receive(:compile).ordered
            expect(update_step).to receive(:update).ordered
            expect(notifier).to receive(:send_end_event).ordered
          end

          it 'performs an update' do
            expect(job.perform).to eq("/deployments/deployment-name")
          end

          it 'cleans up the temporary manifest' do
            job.perform
            expect(File.exist? manifest_path).to be_falsey
          end
        end

        context 'when the first task fails' do
          before do
            expect(job).to receive(:with_deployment_lock).and_yield.ordered
            expect(notifier).to receive(:send_start_event).ordered
            expect(prepare_step).to receive(:prepare).and_raise(Exception).ordered
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
end
