# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::AwsCloud::Cloud do

  it "gets volume ids" do
    fake_instance_id = "fakeinstance"

    cloud = mock_cloud do |ec2, region|
      mock_instance = double("AWS Instance")
      ec2.instances.should_receive(:[]).with(fake_instance_id).and_return(mock_instance)
      mock_instance.should_receive(:block_devices).and_return([
                                                             {
                                                                 :device_name => "/dev/sda2",
                                                                 :ebs => {
                                                                     :volume_id => "vol-123",
                                                                     :status => "attaching",
                                                                     :attach_time => 'time',
                                                                     :delete_on_termination => true
                                                                 }
                                                             }, {
                                                                 :device_name => "/dev/sdb",
                                                                 :virtual_name => "ephemeral0",
                                                             },
                                                             {
                                                                 :device_name => "/dev/sdb2",
                                                                 :ebs => {
                                                                     :volume_id => "vol-456",
                                                                     :status => "attaching",
                                                                     :attach_time => 'time',
                                                                     :delete_on_termination => true
                                                                 }
                                                             }
                                                         ])
    end

    cloud.get_disks(fake_instance_id).should == ["vol-123", "vol-456"]
  end

end
