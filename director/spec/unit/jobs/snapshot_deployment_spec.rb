require 'spec_helper'

describe Bosh::Director::Jobs::SnapshotDeployment do
  let(:deployment_manager) { double(BD::Api::DeploymentManager) }
  let(:deployment_name) { 'deployment' }
  let!(:deployment) { BDM::Deployment.make(name: deployment_name) }
  let!(:instance1) { BDM::Instance.make(deployment: deployment) }
  let!(:instance2) { BDM::Instance.make(deployment: deployment) }
  let!(:instance3) { BDM::Instance.make(deployment: deployment) }
  let!(:instance4) { BDM::Instance.make }

  subject { described_class.new(deployment_name) }

  it 'tells the snapshot manager to snapshot a deployment' do
    BD::Api::DeploymentManager.should_receive(:new).and_return(deployment_manager)

    deployment_manager.should_receive(:find_by_name).with(deployment_name).and_return(deployment)

    # get all the instances
    # call take_snapshot for all the instances
    BD::Api::SnapshotManager.should_receive(:take_snapshot).with(instance1, {})
    BD::Api::SnapshotManager.should_receive(:take_snapshot).with(instance2, {})
    BD::Api::SnapshotManager.should_receive(:take_snapshot).with(instance3, {})
    BD::Api::SnapshotManager.should_not_receive(:take_snapshot).with(instance4, {})

    expect(subject.perform).to eq "snapshots of deployment `deployment' created"
  end
end
