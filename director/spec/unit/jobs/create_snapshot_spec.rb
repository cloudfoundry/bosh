require 'spec_helper'

describe Bosh::Director::Jobs::CreateSnapshot do

  let(:instance) { double(BDM::Instance) }
  let(:options) { {} }

  subject(:job) { described_class.new(instance, options) }

  it 'tells the snapshot manager to create a snapshot' do
    BD::Api::SnapshotManager.should_receive(:take_snapshot).with(instance, options)
    job.perform
  end

end
