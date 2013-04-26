require 'spec_helper'

describe Bosh::Director::Jobs::DeleteSnapshots do

  let(:snapshots) { [] }

  subject(:job) { described_class.new(snapshots) }

  it 'tells the snapshot manager to delete the snapshots' do
    BD::Api::SnapshotManager.should_receive(:delete_snapshots).with(snapshots)
    job.perform
  end

end
