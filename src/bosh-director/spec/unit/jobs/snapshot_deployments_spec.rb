require 'spec_helper'

module Bosh::Director
  describe Jobs::SnapshotDeployments do
    let(:snapshot_manager) { instance_double('Bosh::Director::Api::SnapshotManager') }
    subject { described_class.new(snapshot_manager: snapshot_manager) }

    describe 'DJ job class expectations' do
      let(:job_type) { :snapshot_deployments }
      let(:queue) { :normal }
      it_behaves_like 'a DJ job'
    end

    describe '#perform' do
      let(:deployments) { [Models::Deployment.make, Models::Deployment.make] }
      let(:task1) { instance_double('Bosh::Director::Models::Task', id: 43) }
      let(:task2) { instance_double('Bosh::Director::Models::Task', id: 44) }

      it 'creates snapshot tasks for each deployment' do
        expect(snapshot_manager).to receive(:create_deployment_snapshot_task).with('scheduler', deployments[0]).and_return(task1)
        expect(snapshot_manager).to receive(:create_deployment_snapshot_task).with('scheduler', deployments[1]).and_return(task2)

        subject.perform
      end

      it 'returns a message containing the snapshot task ids' do
        allow(snapshot_manager).to receive(:create_deployment_snapshot_task).with('scheduler', deployments[0]).and_return(task1)
        allow(snapshot_manager).to receive(:create_deployment_snapshot_task).with('scheduler', deployments[1]).and_return(task2)
        expect(subject.perform).to include('43, 44')
      end
    end
  end
end
