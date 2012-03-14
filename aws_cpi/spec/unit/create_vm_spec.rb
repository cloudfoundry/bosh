# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::AWSCloud::Cloud do
  before(:all) do
    @options = mock_cloud_options.merge("agent" => {})
  end

  describe "#create_vm" do
    it "should create a vm" do
      cloud = make_mock_cloud(@options) do |ec2|
        instance = double("instance")
        instance.should_receive(:status).and_return(:mock, :running)
        instance.stub(:id).and_return("id")
        ec2.instances.should_receive(:create).and_return(instance)
      end

      agent_id = "agent_id"
      stemcell_id = "stemcell_id"
      resource_pool = {}
      network_spec = {}

      id = cloud.create_vm(agent_id, stemcell_id, resource_pool, network_spec)
      id.should == "id"
    end
  end

end
