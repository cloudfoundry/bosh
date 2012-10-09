# Copyright (c) 2012 VMware, Inc.

require "spec_helper"

describe "job" do
  before(:all) do
    bosh("upload release #{latest_bat_release}")
    bosh("upload stemcell #{stemcell}")
  end

  after(:all) do
    bosh("delete stemcell bosh-stemcell #{stemcell_version}")
    bosh("delete release bat")
  end

  around(:each) do |example|
    with_deployment(deployment_spec) do |deployment|
      bosh("deployment #{deployment}")
      bosh("deploy")
      example.call
    end
  end

  after(:each) do
    bosh("delete deployment bat")
  end

  it "should restart a job" do
    bosh("restart bat 0").should succeed_with /bat\(0\) has been restarted/
    # TODO verify that the process gets a new pid
  end

  it "should recreate a job" do
    bosh("recreate bat 0").should succeed_with /bat\(0\) has been recreated/
    # TODO verify that the VM gets a new cid
  end

  it "should stop and start a job" do
    bosh("stop bat 0").should succeed_with /bat\(0\) has been stopped/
    bosh("start bat 0").should succeed_with /bat\(0\) has been started/
    # TODO verify that the process gets a new pid
  end

end
