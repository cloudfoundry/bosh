# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

describe Bosh::AwsCloud::Cloud do

  it 'deletes an EC2 instance' do
    instance_manager = double('InstanceManager')
    instance_manager.should_receive(:terminate).with('i-foobar', false)

    registry = mock_registry
    region = nil
    ec2 = mock_cloud do |ec2, r|
      region = r
    end

    Bosh::AwsCloud::InstanceManager.should_receive(:new).with(region, registry).and_return(instance_manager)

    ec2.delete_vm('i-foobar')
  end
end
