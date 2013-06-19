require "spec_helper"

describe "with release and stemcell and two deployments" do

  let(:deployed_regexp) { /Deployed \`.*' to \`.*'/ }

  before(:all) do
    requirement previous_release
    requirement release
    requirement stemcell
    load_deployment_spec
  end

  after(:all) do
    cleanup release
    cleanup previous_release
    cleanup stemcell
  end

  context "deployment without static ip" do

    #before(:all) do
    #  reload_deployment_spec
    #  use_job_instances(3)
    #  use_pool_size(3)
    #  use_max_in_flight(2)
    #  use_canaries(0)
    #  @deployment_result = requirement deployment
    #end
    #
    #after(:all) do
    #  cleanup deployment
    #end


    # Uncomment the before and afters when fixing this test
    xit "should update a job with multiple instances in parallel" do
      times = start_and_finish_times_for_job_updates(get_task_id(@deployment_result.output))
      times["batlight/1"]["started"].should be >= times["batlight/0"]["started"]
      times["batlight/1"]["started"].should be < times["batlight/0"]["finished"]
      times["batlight/2"]["started"].should be >=
                                                [times["batlight/0"]["finished"], times["batlight/1"]["finished"]].min
    end
  end


  xit "should cancel a deployment" do

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

    deployment_names = jbosh("/deployments").map { |deployment| deployment["name"] }
    bosh("delete deployment #{deployment.name}") if deployment_names.include? deployment.name
    deployment.delete
  end

  context "drain" do

    it "should drain when updating", ssh: true do
      reload_deployment_spec
      use_static_ip
      deployment = with_deployment
      bosh("deployment #{deployment.to_path}")
      bosh("deploy").should succeed_with deployed_regexp
      deployment.delete

      use_release("latest")
      with_deployment do
        ssh(static_ip, "vcap", "ls /tmp/drain 2> /dev/null", ssh_options).should
        match %r{/tmp/drain}
      end
    end

    xit "should drain dynamically when updating", ssh: true do
      use_dynamic_drain
      use_release("latest")
      deployment = with_deployment
      bosh("deployment #{deployment.to_path}")
      bosh("deploy").should succeed_with deployed_regexp
      deployment.delete

      use_release(previous_release.version)
      with_deployment do
        output = ssh(static_ip, "vcap", "cat /tmp/drain 2> /dev/null", ssh_options)
        drain_times = output.split.map { |time| time.to_i }
        drain_times.size.should == 3
        (drain_times[1] - drain_times[0]).should be > 3
        (drain_times[2] - drain_times[1]).should be > 4
      end
    end
  end

  context "first deployment" do
    before(:all) do
      reload_deployment_spec
      # using password 'foobar'
      use_password('$6$tHAu4zCTso$pAQok0MTHP4newel7KMhTzMI4tQrAWwJ.X./fFAKjbWkCb5sAaavygXAspIGWn8qVD8FeT.Z/XN4dvqKzLHhl0')
      @our_ssh_options = ssh_options.merge(password: "foobar")
      use_static_ip
      @jobs = %w[
        /var/vcap/packages/batlight/bin/batlight
        /var/vcap/packages/batarang/bin/batarang
      ]
      use_job("colocated")
      use_template(%w[batarang batlight])

      use_persistent_disk(2048)

      @first_deployment_result = requirement deployment
    end

    after(:all) do
      cleanup deployment
    end

    it "should set vcap password", ssh: true do
      ssh(static_ip, "vcap", "echo foobar | sudo -S whoami", @our_ssh_options).should == "[sudo] password for vcap: root\n"
    end

    it "should not change the deployment on a noop" do
      deployment_result = bosh("deploy")
      events(get_task_id(deployment_result.output)).each do |event|
        event["stage"].should_not match /^Updating/
      end
      # TODO validate by checking job pid before and after
    end

    it "should do two deployments from one release" do
      pending "This fails on AWS VPC because use_static_ip only sets the eip but doesn't prevent collision" if aws?
      pending "This fails on OpenStack because use_static_ip only sets the floating IP but doesn't prevent collision" if openstack?

      @first_deployment_result.should succeed_with deployed_regexp

      # second deployment can't use static IP or there will be a collision with the first deployment
      no_static_ip
      use_deployment_name("bat2")
      with_deployment do
        deployments.should include("bat2")
      end
      # Not sure why these are necessary since the before(:all) should call them
      # before setting up future deployments. But without these, the state leaks
      # into subsequent tests.
      use_deployment_name("bat")
      use_static_ip
    end

    it "should use job colocation", ssh: true do
      @jobs.each do |job|
        grep = "pgrep -lf #{job}"
        ssh(static_ip, "vcap", grep, @our_ssh_options).should match %r{#{job}}
      end
    end

    it "should deploy using a static network", ssh: true do
      pending "doesn't work on AWS as the VIP IP isn't visible to the VM" if aws?
      pending "doesn't work on OpenStack as the VIP IP isn't visible to the VM" if openstack?
      ssh(static_ip, "vcap", "ifconfig eth0", @our_ssh_options).should match /#{static_ip}/
    end

    context "second deployment" do
      SAVE_FILE = "/var/vcap/store/batarang/save"

      before(:all) do
        ssh(static_ip, "vcap", "echo 'foobar' > #{SAVE_FILE}", @our_ssh_options)
        @size = persistent_disk(static_ip)
        use_persistent_disk(4096)
        #use_job("batfoo")
        #use_template("batlight")
        @second_deployment_result = requirement deployment
      end

      it "should migrate disk contents", ssh: true do
        persistent_disk(static_ip).should_not == @size
        ssh(static_ip, "vcap", "cat #{SAVE_FILE}", @our_ssh_options).should match /foobar/
      end

      xit "should rename a job" do
        bosh('rename job batlight batfoo').should succeed_with %r{Rename successful}
        bosh('vms').should succeed_with %r{batfoo}
      end
    end
  end
end
