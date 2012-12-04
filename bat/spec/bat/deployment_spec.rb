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
    with_deployment do
      # nothing to check, it is done in the with_deployment helper
    end
  end

  it "should not change the deployment on a noop" do
    with_deployment do |deployment, result|
      result = bosh("deploy")
      events(get_task_id(result.output)).each do |event|
        event["stage"].should_not match /^Updating/
      end
      # TODO validate by checking job pid before and after
    end
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

  it "should use job colocation" do
    pending "director lacks colocation support" unless colocation?
    jobs = %w[
      /var/vcap/packages/batlight/bin/batlight
      /var/vcap/packages/batarang/bin/batarang
    ]
    use_job("composite")
    use_template(%w[batarang batlight])
    use_static_ip
    with_deployment do
      jobs.each do |job|
        grep = "pgrep -lf #{job}"
        ssh(static_ip, "vcap", password, grep).should match %r{#{job}}
      end
    end
  end

  it "should use a canary" do
    use_canaries(1)
    use_pool_size(2)
    use_job_instances(2)
    use_failing_job
    with_deployment do |deployment|
      bosh("deployment #{deployment.to_path}").should succeed
      result = bosh("deploy", :on_error => :return)
      # possibly check for:
      # Error 400007: `batlight/0' is not running after update
      result.should_not succeed

      events(get_task_id(result.output, "error")).each do |event|
        if event["stage"] == "Updating job"
          event["task"].should_not match %r{^batlight/1}
        end
      end

      bosh("delete deployment #{deployment.name}")
      deployment.delete
    end
  end

  it "should update a job with multiple instances in parallel" do
    use_canaries(0)
    use_max_in_flight(2)
    use_job_instances(3)
    use_pool_size(3)
    with_deployment do |deployment, result|
      times = start_and_finish_times_for_job_updates(get_task_id(result.output))
      times["batlight/1"]["started"].should be >= times["batlight/0"]["started"]
      times["batlight/1"]["started"].should be < times["batlight/0"]["finished"]
      times["batlight/2"]["started"].should be >=
          [times["batlight/0"]["finished"], times["batlight/1"]["finished"]].min
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
    with_deployment do |deployment, result|
      bat_vms = vms(deployment.name)
      bat_vms.size.should == 1
      bat_vms.first.name.should == "batlight/0"
    end
  end

  it "should cancel a deployment" do
    deployment = with_deployment
    bosh("deployment #{deployment.to_path}")
    result = bosh("--no-track deploy")
    task_id = get_task_id(result.output, "running")

    sleep 5 # Wait for deployment to start
    bosh("cancel task #{task_id}").should
      succeed_with /Task #{task_id} is getting canceled/

    error_event = events(task_id).last["error"]
    error_event["code"].should == 10001
    error_event["message"].should == "Task #{task_id} cancelled"

    bosh("delete deployment #{deployment.name}")
    deployment.delete
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
