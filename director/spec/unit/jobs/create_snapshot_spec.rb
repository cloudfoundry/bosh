require 'spec_helper'

describe Bosh::Director::Jobs::CreateSnapshot do

  let(:instance) { double(BDM::Instance, id: 0) }
  let(:instance_id) { 0 }
  let(:options) { {} }
  let(:instance_manager) { double(BD::Api::InstanceManager) }
  let(:cids) { %w[snap0 snap1] }

  subject(:job) { described_class.new(instance_id, options) }

  it 'tells the snapshot manager to create a snapshot' do
    BD::Api::InstanceManager.should_receive(:new).and_return(instance_manager)
    instance_manager.should_receive(:find_instance).with(instance_id).and_return(instance)
    BD::Api::SnapshotManager.should_receive(:take_snapshot).with(instance, options).and_return(cids)

    expect(job.perform).to eq 'snapshot(s) snap0, snap1 created'
  end

end
