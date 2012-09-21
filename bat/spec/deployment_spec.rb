# Copyright (c) 2012 VMware, Inc.

require "spec_helper"

describe "deployment" do
  before(:all) do
    bosh!("upload release #{latest_bat_release}")
    bosh!("upload stemcell #{stemcell}")
    bosh!("deployment #{deployment}")
  end

  after(:all) do
    bosh!("delete stemcell bosh-stemcell #{stemcell_version}")
    bosh!("delete release bat")
  end

  after(:each) do
    bosh!("delete deployment bat")
  end

  it "should do an initial deployment" do
    bosh("deploy").should succeed_with /Deployed \`\S+\' to \`\S+'/
  end

  it "should not change the deployment on a noop" do
    bosh("deploy").should succeed_with /Deployed \`\S+\' to \`\S+'/
    result = bosh("deploy")
    result.should succeed_with /Deployed \`\S+\' to \`\S+'/

    task_id = get_task_id(result.output)
    events(task_id).each do |event|
      event["stage"].should_not match /^Updating/
    end

    # TODO validate by checking batarang pid before and after
  end

  describe "network" do
    context "aws" do
      it "should deploy using a dynamic network"
      it "should deploy using a static network"
    end

    context "vsphere" do
      it "should deploy using dynamic network"
      it "should deploy using a static network"
    end
  end
end