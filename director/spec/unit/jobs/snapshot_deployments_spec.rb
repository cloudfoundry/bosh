require 'spec_helper'

module Bosh::Director
  describe Jobs::SnapshotDeployments do
    let(:snapshot_manager) { instance_double('Bosh::Director::Api::SnapshotManager') }
    subject { described_class.new(snapshot_manager: snapshot_manager) }

    describe 'Resque job class expectations' do
      let(:job_type) { :snapshot_deployments }
      it_behaves_like 'a Resque job'
    end

    describe '#perform' do
      let(:deployments) { [Models::Deployment.make, Models::Deployment.make] }
      let(:task1) { instance_double('Bosh::Director::Models::Task', id: 43) }
      let(:task2) { instance_double('Bosh::Director::Models::Task', id: 44) }

      it 'creates snapshot tasks for each deployment' do
        snapshot_manager.should_receive(:create_deployment_snapshot_task).with('scheduler', deployments[0]).and_return(task1)
        snapshot_manager.should_receive(:create_deployment_snapshot_task).with('scheduler', deployments[1]).and_return(task2)

        subject.perform
      end

      it 'returns a message containing the snapshot task ids' do
        snapshot_manager.stub(:create_deployment_snapshot_task).with('scheduler', deployments[0]).and_return(task1)
        snapshot_manager.stub(:create_deployment_snapshot_task).with('scheduler', deployments[1]).and_return(task2)
        expect(subject.perform).to include('43, 44')
      end
    end
  end
end
