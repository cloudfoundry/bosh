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
        expect(ec2.volumes).to receive(:[]).with('vol-xxxxxxxx').and_return(volume)
      end


      expect(volume).to receive(:attachments).and_return([attachment])
      expect(volume).to receive(:create_snapshot).with('deployment/job/0/sdf').and_return(snapshot)

      expect(Bosh::AwsCloud::ResourceWait).to receive(:for_snapshot).with(
        snapshot: snapshot, states: [:pending, :completed]
      )

      expect(Bosh::AwsCloud::TagManager).to receive(:tag).with(snapshot, 'agent_id', 'agent')
      expect(Bosh::AwsCloud::TagManager).to receive(:tag).with(snapshot, 'instance_id', 'instance')
      expect(Bosh::AwsCloud::TagManager).to receive(:tag).with(snapshot, 'director_name', 'Test Director')
      expect(Bosh::AwsCloud::TagManager).to receive(:tag).with(snapshot, 'director_uuid', '6d06b0cc-2c08-43c5-95be-f1b2dd247e18')
      expect(Bosh::AwsCloud::TagManager).to receive(:tag).with(snapshot, 'device', '/dev/sdf')
      expect(Bosh::AwsCloud::TagManager).to receive(:tag).with(snapshot, 'Name', 'deployment/job/0/sdf')

      cloud.snapshot_disk('vol-xxxxxxxx', metadata)
    end

    it 'handles string keys in metadata' do
      cloud = mock_cloud do |ec2|
        expect(ec2.volumes).to receive(:[]).with('vol-xxxxxxxx').and_return(volume)
      end
      metadata = {
        'agent_id' => 'agent',
        'instance_id' => 'instance',
        'director_name' => 'Test Director',
        'director_uuid' => '6d06b0cc-2c08-43c5-95be-f1b2dd247e18',
        'deployment' => 'deployment',
        'job' => 'job',
        'index' => '0'
      }


      allow(volume).to receive(:attachments).and_return([attachment])
      allow(volume).to receive(:create_snapshot).with('deployment/job/0/sdf').and_return(snapshot)

      allow(Bosh::AwsCloud::ResourceWait).to receive(:for_snapshot).with(
          snapshot: snapshot, states: [:pending, :completed]
        )

      expect(Bosh::AwsCloud::TagManager).to receive(:tag).with(snapshot, 'agent_id', 'agent')
      expect(Bosh::AwsCloud::TagManager).to receive(:tag).with(snapshot, 'instance_id', 'instance')
      expect(Bosh::AwsCloud::TagManager).to receive(:tag).with(snapshot, 'director_name', 'Test Director')
      expect(Bosh::AwsCloud::TagManager).to receive(:tag).with(snapshot, 'director_uuid', '6d06b0cc-2c08-43c5-95be-f1b2dd247e18')
      expect(Bosh::AwsCloud::TagManager).to receive(:tag).with(snapshot, 'device', '/dev/sdf')
      expect(Bosh::AwsCloud::TagManager).to receive(:tag).with(snapshot, 'Name', 'deployment/job/0/sdf')

      cloud.snapshot_disk('vol-xxxxxxxx', metadata)
    end

    it 'should take a snapshot of a disk not attached to any instance' do
      cloud = mock_cloud do |ec2|
        expect(ec2.volumes).to receive(:[]).with('vol-xxxxxxxx').and_return(volume)
      end

      expect(volume).to receive(:attachments).and_return([])
      expect(volume).to receive(:create_snapshot).with('deployment/job/0').and_return(snapshot)

      expect(Bosh::AwsCloud::ResourceWait).to receive(:for_snapshot).with(
        snapshot: snapshot, states: [:pending, :completed]
      )

      expect(Bosh::AwsCloud::TagManager).to receive(:tag).with(snapshot, 'agent_id', 'agent')
      expect(Bosh::AwsCloud::TagManager).to receive(:tag).with(snapshot, 'instance_id', 'instance')
      expect(Bosh::AwsCloud::TagManager).to receive(:tag).with(snapshot, 'director_name', 'Test Director')
      expect(Bosh::AwsCloud::TagManager).to receive(:tag).with(snapshot, 'director_uuid', '6d06b0cc-2c08-43c5-95be-f1b2dd247e18')
      expect(Bosh::AwsCloud::TagManager).to receive(:tag).with(snapshot, 'Name', 'deployment/job/0')

      cloud.snapshot_disk('vol-xxxxxxxx', metadata)
    end
  end
end
