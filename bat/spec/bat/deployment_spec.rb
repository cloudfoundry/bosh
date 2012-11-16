# Copyright (c) 2012 VMware, Inc.

require "spec_helper"

describe "deployment" do
  DEPLOYED_REGEXP = /Deployed \`\S+' to \`\S+'/
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

  it "should update a job with multiple instances in parallel" do
    use_canaries(0)
    use_max_in_flight(2)
    use_job_instances(3)
    use_pool_size(3)
    with_deployment do |deployment|
      bosh("deployment #{deployment.to_path}").should succeed
      result = bosh("deploy")
      result.should succeed_with DEPLOYED_REGEXP

      times = start_and_finish_times_for_job_updates(get_task_id(result.output))
      times["batlight/1"]["started"].should be >= times["batlight/0"]["started"]
      times["batlight/1"]["started"].should be < times["batlight/0"]["finished"]
      times["batlight/2"]["started"].should be >=
          [times["batlight/0"]["finished"], times["batlight/1"]["finished"]].min

      bosh("delete deployment #{deployment.name}").should succeed
    end
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

    bosh("delete release #{previous.name} #{previous.version}")
  end

  it "should return vms in a deployment" do
    with_deployment do |deployment|
      bosh("deployment #{deployment.to_path}").should succeed
      bosh("deploy").should succeed_with DEPLOYED_REGEXP

      bat_vms = vms(deployment.name)
      bat_vms.size.should == 1
      bat_vms.first.name.should == "batlight/0"

      bosh("delete deployment #{deployment.name}").should succeed
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

  it "should set vcap password" do
    # using password 'foobar'
    use_password('$6$tHAu4zCTso$pAQok0MTHP4newel7KMhTzMI4tQrAWwJ.X./fFAKjbWkCb5sAaavygXAspIGWn8qVD8FeT.Z/XN4dvqKzLHhl0')
    use_static_ip
    with_deployment do
      ssh(static_ip, "vcap", "foobar", "cat /etc/hosts").should_not == ""
    end
  end
end
