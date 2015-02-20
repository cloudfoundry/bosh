require 'spec_helper'

describe Bosh::AwsCloud::Cloud do
  describe '#delete_snapshot' do
    let(:snapshot) { double(AWS::EC2::Snapshot, id: 'snap-xxxxxxxx') }

    let(:cloud) {
      mock_cloud do |ec2|
        snapshots = double(AWS::EC2::SnapshotCollection, :[] => snapshot)
        allow(ec2).to receive_messages(snapshots: snapshots)
      end
    }

    it 'should delete a snapshot' do
      expect(snapshot).to receive(:status).and_return(:available)
      expect(snapshot).to receive(:delete)

      cloud.delete_snapshot('snap-xxxxxxxx')
    end

    it 'should raise an error if the snapshot is in use' do
      expect(snapshot).to receive(:status).and_return(:in_use)
      expect(snapshot).not_to receive(:delete)

      expect {
        cloud.delete_snapshot('snap-xxxxxxxx')
      }.to raise_error Bosh::Clouds::CloudError, %q{snapshot 'snap-xxxxxxxx' can not be deleted as it is in use}
    end
  end
end
