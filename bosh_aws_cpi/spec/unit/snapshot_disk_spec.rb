require 'spec_helper'

describe Bosh::AwsCloud::Cloud do
  describe '#snapshot_disk' do
    let(:volume) { double(AWS::EC2::Volume, id: 'vol-xxxxxxxx') }
    let(:snapshot) { double(AWS::EC2::Snapshot, id: 'snap-xxxxxxxx') }
    let(:attachment) { double(AWS::EC2::Attachment, device: '/dev/sdf') }
    let(:metadata) {
      {
          agent_id: 'agent',
          instance_id: 'instance',
          director_name: 'Test Director',
          director_uuid: '6d06b0cc-2c08-43c5-95be-f1b2dd247e18',
          deployment: 'deployment',
          job: 'job',
          index: '0'
      }
    }

    it 'should take a snapshot of a disk' do
      cloud = mock_cloud do |ec2|
        ec2.volumes.should_receive(:[]).with('vol-xxxxxxxx').and_return(volume)
      end


      volume.should_receive(:attachments).and_return([attachment])
      volume.should_receive(:create_snapshot).with('deployment/job/0/sdf').and_return(snapshot)

      Bosh::AwsCloud::ResourceWait.should_receive(:for_snapshot).with(
        snapshot: snapshot, state: :completed
      )

      Bosh::AwsCloud::TagManager.should_receive(:tag).with(snapshot, :agent_id, 'agent')
      Bosh::AwsCloud::TagManager.should_receive(:tag).with(snapshot, :instance_id, 'instance')
      Bosh::AwsCloud::TagManager.should_receive(:tag).with(snapshot, :director_name, 'Test Director')
      Bosh::AwsCloud::TagManager.should_receive(:tag).with(snapshot, :director_uuid, '6d06b0cc-2c08-43c5-95be-f1b2dd247e18')
      Bosh::AwsCloud::TagManager.should_receive(:tag).with(snapshot, :device, '/dev/sdf')
      Bosh::AwsCloud::TagManager.should_receive(:tag).with(snapshot, 'Name', 'deployment/job/0/sdf')

      cloud.snapshot_disk('vol-xxxxxxxx', metadata)
    end

    it 'should take a snapshot of a disk not attached to any instance' do
      cloud = mock_cloud do |ec2|
        ec2.volumes.should_receive(:[]).with('vol-xxxxxxxx').and_return(volume)
      end

      volume.should_receive(:attachments).and_return([])
      volume.should_receive(:create_snapshot).with('deployment/job/0').and_return(snapshot)

      Bosh::AwsCloud::ResourceWait.should_receive(:for_snapshot).with(
        snapshot: snapshot, state: :completed
      )

      Bosh::AwsCloud::TagManager.should_receive(:tag).with(snapshot, :agent_id, 'agent')
      Bosh::AwsCloud::TagManager.should_receive(:tag).with(snapshot, :instance_id, 'instance')
      Bosh::AwsCloud::TagManager.should_receive(:tag).with(snapshot, :director_name, 'Test Director')
      Bosh::AwsCloud::TagManager.should_receive(:tag).with(snapshot, :director_uuid, '6d06b0cc-2c08-43c5-95be-f1b2dd247e18')
      Bosh::AwsCloud::TagManager.should_receive(:tag).with(snapshot, 'Name', 'deployment/job/0')

      cloud.snapshot_disk('vol-xxxxxxxx', metadata)
    end
  end
end
