require 'spec_helper'

describe Bosh::Director::Jobs::CreateSnapshot do

  let(:instance) { BDM::Instance.make }
  let(:options) { {} }
  let(:instance_manager) { double(BD::Api::InstanceManager) }
  let(:cids) { %w[snap0 snap1] }

  subject { described_class.new(instance.id, options) }

  describe 'described_class.job_type' do
    it 'returns a symbol representing job type' do
      expect(described_class.job_type).to eq(:create_snapshot)
    end
  end

  it 'tells the snapshot manager to create a snapshot' do
    BD::Api::SnapshotManager.should_receive(:take_snapshot).with(instance, options).and_return(cids)

    expect(subject.perform).to eq 'snapshot(s) snap0, snap1 created'
  end

end
