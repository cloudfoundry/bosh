require 'spec_helper'

describe Bosh::AwsCloud::Cloud do

  describe '#reboot_vm' do
    let(:fake_instance_id) { 'i-xxxxxxxx' }

    it 'should reboot an instance given the id' do
      cloud = mock_cloud(mock_cloud_options['properties'])
      im = double(Bosh::AwsCloud::InstanceManager)
      im.should_receive(:reboot).with(fake_instance_id)
      Bosh::AwsCloud::InstanceManager.stub(:new).and_return(im)
      cloud.reboot_vm(fake_instance_id)
    end
  end
end
