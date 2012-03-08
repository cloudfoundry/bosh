# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe VSphereCloud::Client do
  describe "#find_by_inventory_path"
  it "should handle nil" do

    search_index = double("search_index")
    search_index.should_receive(:find_by_inventory_path) do |arg|
      arg
    end

    service_content = double("service_content")
    service_content.should_receive(:search_index).and_return(search_index)

    si = double(VSphereCloud::Client::Vim::ServiceInstance)
    si.stub(:content).and_return(service_content)

    VSphereCloud::Client::Vim::ServiceInstance.should_receive(:new).and_return(si)
    client = VSphereCloud::Client.new("foo")
    path = client.find_by_inventory_path(["a", "b", nil])
    path.should == "a/b"
  end
end
