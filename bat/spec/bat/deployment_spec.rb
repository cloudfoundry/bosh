# Copyright (c) 2012 VMware, Inc.

require "spec_helper"

describe "deployment" do
  DEPLOYED_REGEXP = /Deployed \`\S+' to \`\S+'/
  DEPLOYMENT_REGEXP = /Deployment set to/

  before(:all) do
    bosh("upload release #{latest_bat_release}")
    bosh("upload stemcell #{stemcell}")
    @deployment = with_deployment(deployment_spec)
  end

  after(:all) do
    bosh("delete stemcell bosh-stemcell #{stemcell_version}")
    bosh("delete release bat")
    FileUtils.rm_f(@deployment)
  end

  after(:each) do
    bosh("delete deployment bat")
  end

  it "should do an initial deployment" do
    bosh("deployment #{@deployment}")
    bosh("deploy").should succeed_with DEPLOYED_REGEXP
  end

  it "should not change the deployment on a noop" do
    bosh("deployment #{@deployment}")
    bosh("deploy").should succeed_with DEPLOYED_REGEXP
    result = bosh("deploy")
    result.should succeed_with DEPLOYED_REGEXP

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

  describe "persistent disk" do
    it "should create a disk" do
      with_deployment(deployment_spec) do |manifest|
        bosh("deployment #{manifest}").should succeed_with DEPLOYMENT_REGEXP
        bosh("deploy").should succeed_with DEPLOYED_REGEXP
        # TODO check that the disk is created
      end
    end

    it "should migrate disk contents" do
      spec = deployment_spec

      spec["properties"]["persistent_disk"] = 2048
      with_deployment(spec) do |manifest|
        bosh("deployment #{manifest}").should succeed_with DEPLOYMENT_REGEXP
        bosh("deploy").should succeed_with DEPLOYED_REGEXP
        # TODO get persistent disk size and save some data there
      end

      spec["properties"]["persistent_disk"] = 4096
      with_deployment(spec) do |manifest|
        bosh("deployment #{manifest}").should succeed_with DEPLOYMENT_REGEXP
        bosh("deploy").should succeed_with DEPLOYED_REGEXP
        # TODO check persistent disk size and that contents are preserved
      end
    end
  end
end
