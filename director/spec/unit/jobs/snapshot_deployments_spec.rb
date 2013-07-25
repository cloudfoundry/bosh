require 'spec_helper'

describe Bosh::Director::Jobs::SnapshotDeployments do
  let(:snapshot_manager) { instance_double('Bosh::Director::Api::SnapshotManager') }
  subject { described_class.new(snapshot_manager: snapshot_manager) }

  describe 'Resque job class expectations' do
    let(:job_type) { :snapshot_deployments }
    it_behaves_like 'a Resque job'
  end

  describe '#perform' do
    let(:deployments) { [BDM::Deployment.make, BDM::Deployment.make] }
    let(:task1) { double('Task', id: 43) }
    let(:task2) { double('Task', id: 44) }

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