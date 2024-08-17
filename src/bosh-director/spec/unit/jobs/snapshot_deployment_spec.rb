require 'spec_helper'

module Bosh::Director
  describe Jobs::SnapshotDeployment do
    let(:deployment_manager) { instance_double('Bosh::Director::Api::DeploymentManager') }
    let(:deployment_name) { 'deployment' }
    let!(:deployment) { FactoryBot.create(:models_deployment, name: deployment_name) }
    let!(:instance1) do
      is = FactoryBot.create(:models_instance, deployment: deployment)
      vm = Models::Vm.make(instance_id: is.id)
      is.active_vm = vm
      is
    end
    let!(:instance2) do
      is = FactoryBot.create(:models_instance, deployment: deployment)
      vm = Models::Vm.make(instance_id: is.id)
      is.active_vm = vm
      is
    end
    let!(:instance3) do
      is = FactoryBot.create(:models_instance, deployment: deployment)
      vm = Models::Vm.make(instance_id: is.id)
      is.active_vm = vm
      is
    end
    let!(:instance4) do
      is = FactoryBot.create(:models_instance)
      vm = Models::Vm.make(instance_id: is.id)
      is.active_vm = vm
      is
    end

    subject { described_class.new(deployment_name) }

    before do
      allow(Api::DeploymentManager).to receive(:new).and_return(deployment_manager)
      allow(deployment_manager).to receive(:find_by_name).and_return(deployment)
    end

    describe 'DJ job class expectations' do
      let(:job_type) { :snapshot_deployment }
      let(:queue) { :normal }
      it_behaves_like 'a DJ job'
    end

    describe '#perform' do

      context 'when snapshotting succeeds' do
        it 'should snapshot all instances in the deployment' do
          expect(Api::SnapshotManager).to receive(:take_snapshot).with(instance1, {})
          expect(Api::SnapshotManager).to receive(:take_snapshot).with(instance2, {})
          expect(Api::SnapshotManager).to receive(:take_snapshot).with(instance3, {})
          expect(Api::SnapshotManager).not_to receive(:take_snapshot).with(instance4, {})

          expect(subject.perform).to eq "snapshots of deployment 'deployment' created"
        end
      end

      context 'when vm is not attached' do
        let!(:instance5) { FactoryBot.create(:models_instance, deployment: deployment, active_vm: nil) }

        it 'should snapshot all instance that have a vms attached' do
          expect(Api::SnapshotManager).to receive(:take_snapshot).with(instance1, {})
          expect(Api::SnapshotManager).to receive(:take_snapshot).with(instance2, {})
          expect(Api::SnapshotManager).to receive(:take_snapshot).with(instance3, {})
          expect(Api::SnapshotManager).not_to receive(:take_snapshot).with(instance5, {})

          expect(subject.perform).to eq "snapshots of deployment 'deployment' created"
        end
      end

      context 'when snapshotting fails' do
        let(:nats_rpc) { instance_double('Bosh::Director::NatsRpc', send_message: nil) }

        before do
          allow(Bosh::Director::Config).to receive(:nats_rpc).and_return(nats_rpc)
        end

        it 'should be shown in the status message' do
          expect(Api::SnapshotManager).to receive(:take_snapshot).with(instance1, {}).and_raise(Bosh::Clouds::CloudError)
          expect(Api::SnapshotManager).to receive(:take_snapshot).with(instance2, {})
          expect(Api::SnapshotManager).to receive(:take_snapshot).with(instance3, {}).and_raise(Bosh::Clouds::CloudError)

          expect(subject.perform).to eq "snapshots of deployment 'deployment' created, with 2 failure(s)"
        end

        it 'should send an alert on the message bus' do
          exception = Bosh::Clouds::CloudError.new('a helpful message')

          expect(nats_rpc).to receive(:send_message) do |subject, payload|
            expect(subject).to eq 'hm.director.alert'
            expect(payload['summary']).to include 'a helpful message'
            expect(payload['summary']).to include 'CloudError'
          end

          expect(Api::SnapshotManager).to receive(:take_snapshot).with(instance1, {}).and_raise(exception)
          expect(Api::SnapshotManager).to receive(:take_snapshot).with(instance2, {})
          expect(Api::SnapshotManager).to receive(:take_snapshot).with(instance3, {})

          subject.perform
        end

        it 'logs the cause of failure' do
          exception = Bosh::Clouds::CloudError.new('a helpful message')
          expect(Api::SnapshotManager).to receive(:take_snapshot).with(instance1, {}).and_raise(exception)
          expect(Api::SnapshotManager).to receive(:take_snapshot).with(instance2, {})
          expect(Api::SnapshotManager).to receive(:take_snapshot).with(instance3, {})

          expect(Bosh::Director::Config.logger).to receive(:error) do |message|
            expect(message).to include("#{instance1.job}/#{instance1.index}")
            expect(message).to include(instance1.vm_cid)
            expect(message).to include('a helpful message')
          end

          subject.perform
        end
      end
    end

    describe '#send_alert' do
      let(:job) { 'job' }
      let(:index) { 0 }
      let(:fake_instance) { double('fake instance', job: job, index: index) }

      let(:nats_rpc) { instance_double('Bosh::Director::NatsRpc', send_message: nil) }

      before do
        allow(Bosh::Director::Config).to receive(:nats_rpc).and_return(nats_rpc)
      end

      it 'sends an alert over NATS on hm.director.alert' do
        Timecop.freeze do
          alert = {
            'id' => 'director',
            'severity' => 3,
            'title' => 'director - snapshot failure',
            'summary' => "failed to snapshot #{job}/#{index}: hello",
            'created_at' => Time.now.to_i,
          }
          expect(nats_rpc).to receive(:send_message).with('hm.director.alert', alert)

          Jobs::SnapshotDeployment.new(deployment_name).send_alert(fake_instance, 'hello')
        end
      end
    end
  end
end
