require 'spec_helper'

module Bosh::Director
  describe Jobs::SnapshotDeployments do
    let(:snapshot_manager) { instance_double('Bosh::Director::Api::SnapshotManager') }
    subject { described_class.new(snapshot_manager: snapshot_manager) }

    describe 'DJ job class expectations' do
      let(:job_type) { :snapshot_deployments }
      let(:queue) { :normal }
      it_behaves_like 'a DelayedJob job'
    end

    describe '#perform' do
      let(:deployments) { [FactoryBot.create(:models_deployment), FactoryBot.create(:models_deployment)] }
      let(:task1) { instance_double('Bosh::Director::Models::Task', id: 43) }
      let(:task2) { instance_double('Bosh::Director::Models::Task', id: 44) }

      it 'creates snapshot tasks for each deployment' do
        expect(snapshot_manager).to receive(:create_deployment_snapshot_task).with('scheduler', deployments[0]).and_return(task1)
        expect(snapshot_manager).to receive(:create_deployment_snapshot_task).with('scheduler', deployments[1]).and_return(task2)

        result = subject.perform

        expect(result).to include('43')
        expect(result).to include('44')
      end
    end
  end
end
