# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::CloudStackCloud::Cloud do

  it "deletes an CloudStack volume" do
    volume = double("volume", :id => "v-foobar")

    cloud = mock_cloud do |compute|
      compute.volumes.should_receive(:get).
        with("v-foobar").and_return(volume)
    end

    volume.should_receive(:state).and_return('Ready')
    volume.should_receive(:destroy).and_return(true)

    cloud.delete_disk("v-foobar")
  end

  it "doesn't delete an CloudStack volume unless it's state is `Ready'" do
    volume = double("volume", :id => "v-foobar")

    cloud = mock_cloud do |openstack|
      openstack.volumes.should_receive(:get).with("v-foobar").and_return(volume)
    end

    volume.should_receive(:state).and_return('Busy')

    expect {
      cloud.delete_disk("v-foobar")
    }.to raise_error(Bosh::Clouds::CloudError,
                     "Cannot delete volume `v-foobar', state is Busy")
  end

end
