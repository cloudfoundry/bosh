require 'spec_helper'

describe Bosh::AwsCloud::Cloud do
  describe '#snapshot_disk' do
    let(:volume) { double(AWS::EC2::Volume, id: 'vol-xxxxxxxx') }
    let(:snapshot) { double(AWS::EC2::Snapshot, id: 'snap-xxxxxxxx') }

    it 'should take a snapshot of a disk' do
      cloud = mock_cloud do |ec2|
        ec2.volumes.should_receive(:[]).with('vol-xxxxxxxx').and_return(volume)
      end

      volume.should_receive(:create_snapshot).and_return(snapshot)

      cloud.snapshot_disk('vol-xxxxxxxx')
    end
  end
end
