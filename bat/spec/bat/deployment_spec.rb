# Copyright (c) 2012 VMware, Inc.

require "spec_helper"

describe "deployment" do
  DEPLOYED_REGEXP = /Deployed \`\S+' to \`\S+'/
  DEPLOYMENT_REGEXP = /Deployment set to/
  SAVE_FILE = "/var/vcap/store/batarang/save"

  before(:all) do
    requirement stemcell
    requirement release
  end

  after(:all) do
    cleanup release
    cleanup stemcell
  end

  before(:each) do
    load_deployment_spec
  end

  it "should do an initial deployment" do
    deployment = with_deployment
    deployments.should_not include(deployment.name)
    bosh("deployment #{deployment.to_path}").should succeed
    bosh("deploy").should succeed_with DEPLOYED_REGEXP
    deployments.should include(deployment.name)
    bosh("delete deployment #{deployment.name}").should succeed
    deployment.delete
  end

  it "should not change the deployment on a noop" do
    deployment = with_deployment
    bosh("deployment #{deployment.to_path}").should succeed
    bosh("deploy").should succeed

    result = bosh("deploy")
    result.should succeed_with DEPLOYED_REGEXP

    task_id = get_task_id(result.output)
    events(task_id).each do |event|
      event["stage"].should_not match /^Updating/
    end
    # TODO validate by checking job pid before and after

    bosh("delete deployment #{deployment.name}")
    deployment.delete
  end

  it "should do two deployments from one release" do
    deployment = with_deployment
    name = deployment.name
    bosh("deployment #{deployment.to_path}")
    bosh("deploy").should succeed_with DEPLOYED_REGEXP

    # or there will be an IP collision with the other deployment
    use_static_ip
    use_deployment_name("bat2")
    with_deployment do
      deployments.should include("bat2")
    end

    bosh("delete deployment #{name}")
    deployment.delete
  end

  it "should drain when updating" do
    use_static_ip

    previous = release.previous
    use_release(previous.version)
    bosh("upload release #{previous.to_path}")

    deployment = with_deployment
    bosh("deployment #{deployment.to_path}")
    bosh("deploy").should succeed_with DEPLOYED_REGEXP
    deployment.delete

    use_release("latest")
    with_deployment do
      ssh(static_ip, "vcap", password, "ls /tmp/drain 2> /dev/null").should
        match %r{/tmp/drain}
    end
  end

  describe "network" do
    it "should deploy using dynamic network"

    it "should deploy using a static network" do
      use_static_ip
      with_deployment do
        if aws?
          pending "doesn't work on AWS as the VIP IP isn't visible to the VM"
        else
          ssh(static_ip, "vcap", password, "ifconfig eth0").should
            match /#{static_ip}/
        end
      end
    end
  end

  describe "persistent disk" do
    it "should create a disk" do
      use_static_ip
      use_job("batarang")
      use_persistent_disk(2048)
      with_deployment do
        persistent_disk(static_ip).should_not be_nil
      end
    end

    it "should migrate disk contents" do
      use_static_ip
      use_job("batarang")
      size = nil

      use_persistent_disk(2048)
      deployment = with_deployment
      bosh("deployment #{deployment.to_path}")
      bosh("deploy")

      ssh(static_ip, "vcap", password, "echo 'foobar' > #{SAVE_FILE}")
      size = persistent_disk(static_ip)
      size.should_not be_nil

      use_persistent_disk(4096)
      with_deployment do
        persistent_disk(static_ip).should_not == size
        ssh(static_ip, "vcap", password, "cat #{SAVE_FILE}").should match /foobar/
      end
      deployment.delete
    end
  end
end
