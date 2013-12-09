# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::CloudStackCloud::Cloud do

  it "deletes stemcell" do
    image = double("image", :id => "i-foo", :name => "i-foo", :properties => {})

    cloud = mock_cloud do |compute|
      compute.should_receive(:images).and_return([image])
    end

    image.should_receive(:destroy)

    cloud.delete_stemcell("i-foo")
  end

end
