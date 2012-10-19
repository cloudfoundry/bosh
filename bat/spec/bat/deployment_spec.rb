# Copyright (c) 2012 VMware, Inc.

require "spec_helper"

describe "deployment" do
  DEPLOYED_REGEXP = /Deployed \`\S+' to \`\S+'/
  DEPLOYMENT_REGEXP = /Deployment set to/
  SAVE_FILE = "/var/vcap/store/batarang/save"

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

  it "should do two deployments from one release" do
    bosh("deployment #{@deployment}")
    bosh("deploy").should succeed_with DEPLOYED_REGEXP

    spec = deployment_spec.dup
    # or there will be an IP collision with the other deployment
    use_static_ip(spec)
    spec["properties"]["name"] = "bat2"
    with_deployment(spec) do |deployment|
      bosh("deployment #{deployment}")
      bosh("deploy").should succeed_with DEPLOYED_REGEXP
      bosh("delete deployment bat2")
    end
  end

  it "should drain when updating" do
    spec = deployment_spec
    host = static_ip(spec)
    use_static_ip(spec)

    bosh("upload release #{previous_bat_release}")
    spec["properties"]["release"] = previous_bat_version
    with_deployment(spec) do |deployment|
      bosh("deployment #{deployment}")
      bosh("deploy").should succeed_with DEPLOYED_REGEXP
    end

    spec["properties"]["release"] = "latest"
    with_deployment(spec) do |deployment|
      bosh("deployment #{deployment}")
      bosh("deploy").should succeed_with DEPLOYED_REGEXP

      # drain script creates $TMPDIR/drain
      ssh(host, "vcap", password, "ls /tmp/drain 2> /dev/null").should
        match %r{/tmp/drain}
    end
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
      spec = deployment_spec
      use_static_ip(spec)
      use_persistent_disk(spec, 2048)
      with_deployment(spec) do |manifest|
        bosh("deployment #{manifest}").should succeed_with DEPLOYMENT_REGEXP
        bosh("deploy").should succeed_with DEPLOYED_REGEXP

        persistent_disk(static_ip(spec)).should_not be_nil
      end
    end

    it "should migrate disk contents" do
      spec = deployment_spec
      host = static_ip(spec)
      use_static_ip(spec)
      size = nil

      use_persistent_disk(spec, 2048)
      with_deployment(spec) do |manifest|
        bosh("deployment #{manifest}").should succeed_with DEPLOYMENT_REGEXP
        bosh("deploy").should succeed_with DEPLOYED_REGEXP
        ssh(host, "vcap", password, "echo 'foobar' > #{SAVE_FILE}")
        size = persistent_disk(host)
        size.should_not be_nil
      end

      use_persistent_disk(spec, 4096)
      with_deployment(spec) do |manifest|
        bosh("deployment #{manifest}").should succeed_with DEPLOYMENT_REGEXP
        bosh("deploy").should succeed_with DEPLOYED_REGEXP
        persistent_disk(host).should_not == size
        ssh(host, "vcap", password, "cat #{SAVE_FILE}").should match /foobar/
      end
    end
  end
end
