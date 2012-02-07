require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::DeploymentPlan do

  BASIC_MANIFEST = {
    "name" => "test_deployment",
    "release" => {
      "name" => "test_release",
      "version" => 1
    },
    "compilation" => {
      "workers" => 2,
      "network" => "network_a",
      "cloud_properties" => {
        "ram" => "512mb",
        "disk" => "2gb",
        "cpu" => 1
      }
    },
    "update" => {
      "canaries" => 1,
      "canary_watch_time" => 30000,
      "update_watch_time" => 10000,
      "max_in_flight" => 5,
      "max_errors" => 2
    },
    "networks" => [
      {
        "name" => "network_a",
        "subnets" => [
          {
            "range" => "10.0.0.0/24",
            "gateway" => "10.0.0.1",
            "dns" => ["1.2.3.4"],
            "static" => ["10.0.0.100 - 10.0.0.200"],
            "reserved" => ["10.0.0.201 - 10.0.0.254"],
            "cloud_properties" => {
              "name" => "net_a"
            }
          }
        ]
      }
    ],
    "resource_pools" => [
      {
        "name" => "small",
        "size" => 10,
        "stemcell" => {
          "name" => "jeos",
          "version" => 1
        },
        "network" => "network_a",
        "cloud_properties" => {
          "ram" => "512mb",
          "disk" => "2gb",
          "cpu" => 1
        }
      }
    ],
    "jobs" => [
      {
        "name" => "job_a",
        "template" => "job_a",
        "instances" => 5,
        "resource_pool" => "small",
        "persistent_disk" => 2048,
        "networks" => [
          {
            "name" => "network_a",
            "static_ips" => ["10.0.0.100 - 10.0.0.104"]
          }
        ]
      }
    ],
    "properties" => {"test" => "property"}
  }

  def basic_manifest
    BASIC_MANIFEST._deep_copy
  end

  def make_plan(manifest = BASIC_MANIFEST, options = { })
    Bosh::Director::DeploymentPlan.new(manifest._deep_copy, options)
  end

  describe "Basic parsing" do

    it "should parse a deployment manifest" do
      deployment = make_plan
      deployment.name.should eql("test_deployment")
      deployment.canonical_name.should eql("test-deployment")
    end

    it "should parse the release spec from the deployment manifest" do
      deployment_plan = make_plan

      release_spec = deployment_plan.release
      release_spec.name.should eql("test_release")
      release_spec.version.should eql("1")
      release_spec.release.should be_nil
      release_spec.deployment.should eql(deployment_plan)
    end

    it "should parse the networks from the deployment manifest" do
      deployment_plan = make_plan

      networks = deployment_plan.networks
      networks.size.should eql(1)

      network = networks[0]
      network.should eql(deployment_plan.network("network_a"))
      network.name.should eql("network_a")
      network.canonical_name.should eql("network-a")
      network.deployment.should eql(deployment_plan)
    end

    it "should parse the resource pools from the deployment manifest" do
      deployment_plan = make_plan

      network = deployment_plan.network("network_a")
      resource_pools = deployment_plan.resource_pools
      resource_pools.size.should eql(1)

      resource_pool = resource_pools[0]
      resource_pool.should eql(deployment_plan.resource_pool("small"))
      resource_pool.name.should eql("small")
      resource_pool.cloud_properties.should eql({"cpu" => 1, "ram" => "512mb", "disk" => "2gb"})
      resource_pool.network.should eql(network)
      resource_pool.size.should eql(10)
      resource_pool.idle_vms.should eql([])
      resource_pool.deployment.should eql(deployment_plan)
      resource_pool.spec.should eql({"stemcell" => {"name" => "jeos", "version" => "1"},
                                      "name" => "small",
                                      "cloud_properties" => {"cpu" => 1, "ram" => "512mb", "disk" => "2gb"}})
    end

    it "should parse the stemcell from the deployment manifest" do
      deployment_plan = make_plan

      resource_pool = deployment_plan.resource_pool("small")
      stemcell = resource_pool.stemcell

      stemcell.name.should eql("jeos")
      stemcell.version.should eql("1")
      stemcell.stemcell.should be_nil
      stemcell.resource_pool.should eql(resource_pool)
      stemcell.spec.should eql({"name" => "jeos", "version" => "1"})
    end

    it "should parse the jobs from the deployment manifest" do
      deployment_plan = make_plan

      jobs = deployment_plan.jobs
      jobs.size.should eql(1)

      resource_pool = deployment_plan.resource_pool("small")

      job = jobs[0]

      job.should eql(deployment_plan.job("job_a"))
      job.name.should eql("job_a")
      job.canonical_name.should eql("job-a")
      job.persistent_disk.should eql(2048)
      job.resource_pool.should eql(resource_pool)
      job.template.name.should eql("job_a")
      job.package_spec.should eql({})
      job.state.should be_nil
      job.instance_states.should == { }
    end

    it "should allow overriding job and instance states via options" do
      manifest = basic_manifest

      manifest["jobs"] << {
        "name" => "job_b",
        "template" => "job_b",
        "instances" => 3,
        "resource_pool" => "small",
        "persistent_disk" => 2048,
        "networks" => \
        [
         {
           "name" => "network_a",
           "static_ips" => ["10.0.0.105 - 10.0.0.107"]
         }
        ]
      }

      manifest["jobs"][0]["state"] = "stopped"
      manifest["jobs"][0]["instance_states"] = { 2 => "started" }
      manifest["jobs"][1]["instance_states"] = { 2 => "stopped" }

      job_state_overrides = {
        "job_a" => {
          "instance_states" => {
            3 => "started",
            4 => "detached"
          }
        },
        "job_b" => {
          "state" => "detached",
          "instance_states" => {
            0 => "stopped",
            2 => "started"
          }
        }
      }

      plan = make_plan(manifest, "job_states" => job_state_overrides)
      plan.jobs[0].state.should == "stopped"
      plan.jobs[1].state.should == "detached"

      plan.jobs[0].instances.map { |instance| instance.state }.should == ["stopped", "stopped", "started", "started", "detached"]
      plan.jobs[1].instances.map { |instance| instance.state }.should == ["stopped", "detached", "started"]
    end

    it "should parse job and instance states from the deployment manifest" do
      manifest = basic_manifest
      manifest["jobs"][0]["state"] = "stopped"
      manifest["jobs"][0]["instance_states"] = { 2 => "started" }
      plan = make_plan(manifest)

      job = plan.jobs[0]
      job.state.should == "stopped"
      job.instance_states.should == {
        2 => "started"
      }

      job.instances.map { |instance| instance.state }.should == ["stopped", "stopped", "started", "stopped", "stopped"]
    end

    it "should whine on invalid state settings" do
      manifest = basic_manifest
      manifest["jobs"][0]["state"] = "zb"

      lambda {
        make_plan(manifest)
      }.should raise_error ArgumentError, "Job 'job_a' has an unknown state 'zb', valid states are: started, stopped, detached, recreate, restart"

      manifest["jobs"][0]["state"] = "started"
      manifest["jobs"][0]["instance_states"] = { 12 => "stopped" }

      lambda {
        make_plan(manifest)
      }.should raise_error ArgumentError, "Job 'job_a' instance state '12' is outside of (0..4) range"

      manifest["jobs"][0]["instance_states"] = { 2 => "zb" }

      lambda {
        make_plan(manifest)
      }.should raise_error ArgumentError, "Job 'job_a' instance '2' has an unknown state 'zb', valid states are: started, stopped, detached, recreate, restart"
    end

    it "should parse the instances from the deployment manifest" do
      deployment_plan = make_plan

      job = deployment_plan.job("job_a")
      instances = job.instances
      instances.size.should eql(5)

      instance_1 = instances[0]
      instance_1.should eql(job.instance(0))
      instance_1.job.should eql(job)
      instance_1.index.should eql(0)
      instance_1.current_state.should be_nil
    end

    it "should parse the instance network from the deployment manifest" do
      deployment_plan = make_plan

      job = deployment_plan.job("job_a")
      instance = job.instance(0)
      instance.network_settings.should eql({"network_a" => {
        "netmask" => "255.255.255.0",
        "ip" => "10.0.0.100",
        "default" => ["dns", "gateway"],
        "gateway" => "10.0.0.1",
        "cloud_properties" => {"name" => "net_a"},
        "dns" => ["1.2.3.4"]
      }})

      networks = instance.networks
      networks.size.should eql(1)

      network = networks[0]
      network.should eql(instance.network("network_a"))
      network.name.should eql("network_a")
      network.reserved.should eql(false)
      network.instance.should eql(instance)
      network.ip.should eql(NetAddr::CIDR.create("10.0.0.100").to_i)
    end

    it "should parse the update settings from the deployment manifest" do
      deployment_plan = make_plan

      update_settings = deployment_plan.update
      update_settings.canaries.should eql(1)
      update_settings.min_canary_watch_time.should == 30000
      update_settings.max_canary_watch_time.should == 30000
      update_settings.max_in_flight.should eql(5)
      update_settings.min_update_watch_time.should == 10000
      update_settings.max_update_watch_time.should == 10000
      update_settings.max_errors.should eql(2)

      update_settings = deployment_plan.job("job_a").update
      update_settings.canaries.should eql(1)
      update_settings.min_canary_watch_time.should == 30000
      update_settings.max_canary_watch_time.should == 30000
      update_settings.max_in_flight.should eql(5)
      update_settings.min_update_watch_time.should == 10000
      update_settings.max_update_watch_time.should == 10000
      update_settings.max_errors.should eql(2)
    end

    it "should parse the update settings from the deployment manifest with inheritance" do
      manifest = basic_manifest
      manifest["jobs"][0]["update"] = {
        "canaries" => 2,
        "canary_watch_time" => 1000,
        "max_in_flight" => 3,
        "update_watch_time" => 500,
        "max_errors" => -1
      }

      deployment_plan = make_plan(manifest)

      update_settings = deployment_plan.update
      update_settings.canaries.should eql(1)
      update_settings.min_canary_watch_time.should == 30000
      update_settings.max_canary_watch_time.should == 30000
      update_settings.max_in_flight.should eql(5)
      update_settings.min_update_watch_time.should == 10000
      update_settings.max_update_watch_time.should == 10000
      update_settings.max_errors.should eql(2)

      update_settings = deployment_plan.job("job_a").update
      update_settings.canaries.should eql(2)
      update_settings.min_canary_watch_time.should == 1000
      update_settings.max_canary_watch_time.should == 1000
      update_settings.max_in_flight.should eql(3)
      update_settings.min_update_watch_time.should == 500
      update_settings.max_update_watch_time.should == 500
      update_settings.max_errors.should eql(-1)
    end

    it "should parse min and max watch times from the deployment manifest (w/inheritance)" do
      manifest = basic_manifest
      manifest["update"]["canary_watch_time"] = "100-200"
      manifest["update"]["update_watch_time"] = "300-400"

      manifest["jobs"][0]["update"] = {
        "canaries" => 2,
        "canary_watch_time" => "1000 - 2400",
        "max_in_flight" => 3,
        "update_watch_time" => 3800,
        "max_errors" => -1
      }

      deployment_plan = make_plan(manifest)
      update_spec = deployment_plan.update

      update_spec.min_canary_watch_time.should == 100
      update_spec.max_canary_watch_time.should == 200

      update_spec.min_update_watch_time.should == 300
      update_spec.max_update_watch_time.should == 400

      job_update_spec = deployment_plan.job("job_a").update

      job_update_spec.min_canary_watch_time.should == 1000
      job_update_spec.max_canary_watch_time.should == 2400

      job_update_spec.min_update_watch_time.should == 3800
      job_update_spec.max_update_watch_time.should == 3800
    end

    it "should whine on invalid watch times" do
      ["a-b", "test", "2300a", "3-zb"].each do |value|
        ["canary_watch_time", "update_watch_time"].each do |property|
          manifest = basic_manifest
          manifest["update"][property] = value

          lambda {
            make_plan(manifest)
          }.should raise_error(ArgumentError, "Watch time should be an integer or a range of two integers")
        end
      end

      ["canary_watch_time", "update_watch_time"].each do |property|
        manifest = basic_manifest
        manifest["update"][property] = "100-10"

        lambda {
          make_plan(manifest)
        }.should raise_error(ArgumentError, "Min watch time cannot be greater than max watch time")
      end
    end

    it "should parse the compilation settings from the deployment manifest" do
      deployment_plan = make_plan

      compilation_settings = deployment_plan.compilation
      compilation_settings.workers.should eql(2)
      compilation_settings.network.should eql(deployment_plan.network("network_a"))
      compilation_settings.cloud_properties.should eql({"ram" => "512mb", "cpu" => 1, "disk" => "2gb"})
    end

    it "should parse deployment properties" do
      manifest = basic_manifest
      manifest["properties"] = {"foo" => "bar"}

      deployment_plan = make_plan(manifest)
      deployment_plan.properties.should eql({"foo" => "bar"})
    end

    it "should let you override properties at the job level" do
      manifest = basic_manifest
      manifest["properties"] = {"foo" => "bar", "test" => {"a" => 5, "b" => 6}}
      manifest["jobs"][0]["properties"] = {"test" => {"b" => 7}}

      deployment_plan = make_plan(manifest)
      deployment_plan.properties.should eql({"foo" => "bar", "test" => {"a" => 5, "b" => 6}})
      deployment_plan.job("job_a").properties.should eql({"foo" => "bar", "test" => {"a" => 5, "b" => 7}})
    end

  end

  describe "Jobs" do

    it "should preserve job order" do
      manifest = basic_manifest
      job = manifest["jobs"].first
      job["instances"] = 1
      job["networks"] = [{"name" => "network_a"}]

      5.times do |index|
        new_job = job._deep_copy
        new_job["name"] = "job_a_#{index}"
        manifest["jobs"] << new_job
      end

      deployment_plan = make_plan(manifest)
      jobs = deployment_plan.jobs
      jobs[0].name.should eql("job_a")
      jobs[1].name.should eql("job_a_0")
      jobs[2].name.should eql("job_a_1")
      jobs[3].name.should eql("job_a_2")
      jobs[4].name.should eql("job_a_3")
      jobs[5].name.should eql("job_a_4")
    end

    it "should reject jobs that violate canonical uniqueness" do
      manifest = basic_manifest
      job_a = manifest["jobs"].first
      job_a["instances"] = 1
      job_a["networks"] = [{"name" => "network_a"}]

      job_b = job_a._deep_copy
      job_b["name"] = "job-a"
      manifest["jobs"] << job_b

      lambda {
        make_plan(manifest)
      }.should raise_error("Invalid job name: 'job-a', canonical name already taken.")
    end

    it "should fail when the number of instances exceeds resource pool capacity" do
      manifest = basic_manifest
      manifest["jobs"].first["instances"] = 15
      lambda {
        make_plan(manifest)
      }.should raise_error("Resource pool 'small' is not big enough to run all the requested jobs")
    end


    it "should fail if the resource pool doesn't exist" do
      manifest = basic_manifest
      job = manifest["jobs"].first
      job["resource_pool"] = "bad"

      lambda {
        make_plan(manifest)
      }.should raise_error("Job job_a references an unknown resource pool: bad")
    end

    it "should fail if network name doesn't exist" do
      manifest = basic_manifest
      job = manifest["jobs"].first

      job["networks"] = [
        {
          "name" => "network_b",
          "static_ips" => ["10.0.0.100 - 10.0.0.104"]
        }
      ]

      lambda {
        make_plan(manifest)
      }.should raise_error("Job 'job_a' references an unknown network: 'network_b'")
    end

    it "should fail if no networks were specified" do
      manifest = basic_manifest
      job = manifest["jobs"].first

      job["networks"] = []

      lambda {
        make_plan(manifest)
      }.should raise_error("Job job_a must specify at least one network")
    end

    it "should let you set a default network" do
      manifest = basic_manifest
      job = manifest["jobs"].first

      networks = manifest["networks"]
      networks << {
        "name" => "network_b",
        "subnets" => [
          {
            "range" => "10.1.0.0/24",
            "gateway" => "10.1.0.1",
            "dns" => ["1.2.3.4"],
            "static" => ["10.1.0.100 - 10.1.0.200"],
            "reserved" => ["10.1.0.201 - 10.1.0.254"],
            "cloud_properties" => {
              "name" => "net_b"
            }
          }
        ]
      }

      job["networks"] = [
        { "name" => "network_a", "default" => ["gateway"] },
        { "name" => "network_b", "default" => ["dns"] }
      ]

      deployment_plan = make_plan(manifest)
      deployment_plan.job("job_a").default_network["gateway"].should == "network_a"
      deployment_plan.job("job_a").default_network["dns"].should == "network_b"
    end

    it "should automatically set the default network if there was only one network configured" do
      make_plan.job("job_a").default_network.should == {"gateway"=>"network_a", "dns"=>"network_a"}
    end

    it "should require a default network if more than one network was configured" do
      manifest = basic_manifest
      job = manifest["jobs"].first

      networks = manifest["networks"]
      networks << {
        "name" => "network_b",
        "subnets" => [
          {
            "range" => "10.1.0.0/24",
            "gateway" => "10.1.0.1",
            "dns" => ["1.2.3.4"],
            "static" => ["10.1.0.100 - 10.1.0.200"],
            "reserved" => ["10.1.0.201 - 10.1.0.254"],
            "cloud_properties" => {
              "name" => "net_b"
            }
          }
        ]
      }

      job["networks"] = [
        { "name" => "network_a" },
        { "name" => "network_b" }
      ]

      lambda {
        make_plan(manifest)
      }.should raise_error("Job job_a must specify a default network for 'dns, gateway' since it has more than " +
                               "one network configured")
    end

    it "should fail if more than one default network was configured" do
      manifest = basic_manifest
      job = manifest["jobs"].first

      networks = manifest["networks"]
      networks << {
        "name" => "network_b",
        "subnets" => [
          {
            "range" => "10.1.0.0/24",
            "gateway" => "10.1.0.1",
            "dns" => ["1.2.3.4"],
            "static" => ["10.1.0.100 - 10.1.0.200"],
            "reserved" => ["10.1.0.201 - 10.1.0.254"],
            "cloud_properties" => {
              "name" => "net_b"
            }
          }
        ]
      }

      job["networks"] = [
        { "name" => "network_a", "default" => ["dns", "gateway"] },
        { "name" => "network_b", "default" => ["gateway"] }
      ]

      lambda {
        make_plan(manifest)
      }.should raise_error("Job job_a must specify only one default network for: gateway")
    end
  end

  describe "Resource pools" do

    it "should manage resource pool allocations" do
      deployment_plan = make_plan
      resource_pool = deployment_plan.resource_pool("small")

      resource_pool.idle_vms.size.should eql(0)
      resource_pool.size.should eql(10)

      resource_pool.mark_active_vm
      resource_pool.active_vms.should eql(1)

      idle_vm = resource_pool.add_idle_vm
      resource_pool.idle_vms.should == [idle_vm]
      idle_vm.resource_pool.should eql(resource_pool)
      idle_vm.vm.should be_nil
      idle_vm.ip.should be_nil
      idle_vm.current_state.should be_nil

      allocated_vm = resource_pool.allocate_vm
      resource_pool.idle_vms.should be_empty
      resource_pool.allocated_vms.should == [idle_vm]
      allocated_vm.should eql(idle_vm)
    end

    it "should not let you reserve more VMs than available" do
      deployment_plan = make_plan
      resource_pool = deployment_plan.resource_pool("small")

      lambda {11.times {resource_pool.reserve_vm}}.should raise_error
    end

    it "should track idle vm change state (no change)" do
      deployment_plan = make_plan
      resource_pool = deployment_plan.resource_pool("small")

      idle_vm = resource_pool.add_idle_vm
      idle_vm.ip = NetAddr::CIDR.create("10.0.0.20").to_i
      idle_vm.vm = Bosh::Director::Models::Vm.make

      idle_vm.current_state = {
        "networks" => {
          "network_a" => {
            "netmask" => "255.255.255.0",
            "ip" => "10.0.0.20",
            "default" => ["dns", "gateway"],
            "gateway" => "10.0.0.1",
            "cloud_properties" => {"name" => "net_a"},
            "dns" => ["1.2.3.4"]
          }
        },
        "resource_pool" => {
          "stemcell" => {"name" => "jeos", "version" => "1"},
          "name" => "small",
          "cloud_properties" => {"cpu" => 1, "ram" => "512mb", "disk" => "2gb"}
        }
      }

      idle_vm.networks_changed?.should be_false
      idle_vm.resource_pool_changed?.should be_false
      idle_vm.changed?.should be_false
    end

    it "should track idle vm change state (network change)" do
      deployment_plan = make_plan
      resource_pool = deployment_plan.resource_pool("small")

      idle_vm = resource_pool.add_idle_vm
      idle_vm.ip = NetAddr::CIDR.create("10.0.0.20").to_i
      idle_vm.vm = Bosh::Director::Models::Vm.make

      idle_vm.current_state = {
        "networks" => {
          "network_b" => {
            "netmask" => "255.255.255.0",
            "ip" => "10.0.0.20",
            "gateway" => "10.0.0.1",
            "cloud_properties" => {"name" => "net_a"},
            "dns" => ["1.2.3.4"]
          }
        },
        "resource_pool" => {
          "stemcell" => {"name" => "jeos", "version" => "1"},
          "name" => "small",
          "cloud_properties" => {"cpu" => 1, "ram" => "512mb", "disk" => "2gb"}
        }
      }

      idle_vm.networks_changed?.should be_true
      idle_vm.resource_pool_changed?.should be_false
      idle_vm.changed?.should be_true
    end

    it "should track idle vm change state (resource pool change)" do
      deployment_plan = make_plan
      resource_pool = deployment_plan.resource_pool("small")

      idle_vm = resource_pool.add_idle_vm
      idle_vm.ip = NetAddr::CIDR.create("10.0.0.20").to_i
      idle_vm.vm = Bosh::Director::Models::Vm.make

      idle_vm.current_state = {
        "networks" => {
          "network_a" => {
            "netmask" => "255.255.255.0",
            "ip" => "10.0.0.20",
            "default" => ["dns", "gateway"],
            "gateway" => "10.0.0.1",
            "cloud_properties" => {"name" => "net_a"},
            "dns" => ["1.2.3.4"]
          }
        },
        "resource_pool" => {
          "stemcell" => {"name" => "jeos", "version" => "1"},
          "name" => "small",
          "cloud_properties" => {"cpu" => 2, "ram" => "512mb", "disk" => "2gb"}
        }
      }

      idle_vm.networks_changed?.should be_false
      idle_vm.resource_pool_changed?.should be_true
      idle_vm.changed?.should be_true
    end

    it "should return the network settings for the assigned IP" do
      deployment_plan = make_plan
      resource_pool = deployment_plan.resource_pool("small")

      idle_vm = resource_pool.add_idle_vm
      idle_vm.ip = "10.0.0.50"

      idle_vm.network_settings.should == {
          "network_a" => {
            "netmask" => "255.255.255.0",
            "ip" => "10.0.0.50",
            "default" => ["dns", "gateway"],
            "gateway" => "10.0.0.1",
            "cloud_properties" => {"name" => "net_a"},
            "dns" => ["1.2.3.4"]
          }
        }
    end

    it "should return the network settings for the bound instance if available" do
      deployment_plan = make_plan
      resource_pool = deployment_plan.resource_pool("small")

      instance_spec = mock("instance_spec")
      instance_spec.stub!(:network_settings).and_return({"network_a" => {"ip" => "foo"}})

      idle_vm = resource_pool.add_idle_vm
      idle_vm.bound_instance = instance_spec

      idle_vm.network_settings.should == {"network_a" => {"ip" => "foo"}}
    end

    it "should fail if network name doesn't exist" do
      manifest = basic_manifest
      resource_pool = manifest["resource_pools"].first
      resource_pool["network"] = "network_b"

      lambda {
        make_plan(manifest)
      }.should raise_error("Resource pool 'small' references an unknown network: 'network_b'")
    end
  end

  describe "Networks" do

    it "should manage network allocations" do
      deployment_plan = make_plan
      network = deployment_plan.network("network_a")

      starting_ip = NetAddr::CIDR.create("10.0.0.2")

      97.times do |index|
        network.reserve_ip(starting_ip.to_i + index)
      end

      NetAddr::CIDR.create(network.allocate_dynamic_ip).ip.should eql("10.0.0.99")
    end

    it "should allow gateways to be optional" do
      manifest = basic_manifest
      manifest["networks"][0]["subnets"][0] = {
        "range" => "10.0.0.0/24",
        "dns" => ["1.2.3.4"],
        "static" => ["10.0.0.100 - 10.0.0.200"],
        "reserved" => ["10.0.0.201 - 10.0.0.254"],
        "cloud_properties" => {
          "name" => "net_a"
        }
      }
      deployment_plan = make_plan(manifest)
      network = deployment_plan.network("network_a")
      network.network_settings("10.0.0.2", nil).should == {
        "netmask" => "255.255.255.0",
        "ip" => "10.0.0.2",
        "cloud_properties" => {"name" => "net_a"},
        "dns"=>["1.2.3.4"]
      }
    end

    it "should allow DNS to be optional" do
      manifest = basic_manifest
      manifest["networks"][0]["subnets"][0] = {
        "range" => "10.0.0.0/24",
        "static" => ["10.0.0.100 - 10.0.0.200"],
        "reserved" => ["10.0.0.201 - 10.0.0.254"],
        "cloud_properties" => {
          "name" => "net_a"
        }
      }
      deployment_plan = make_plan(manifest)
      network = deployment_plan.network("network_a")
      network.network_settings("10.0.0.2", nil).should == {
        "netmask" => "255.255.255.0",
        "ip" => "10.0.0.2",
        "cloud_properties" => {"name" => "net_a"}
      }
    end

    it "should allow reserved ranges to be optional" do
      manifest = basic_manifest
      manifest["networks"][0]["subnets"][0] = {
        "range" => "10.0.0.0/24",
        "gateway" => "10.0.0.1",
        "dns" => ["1.2.3.4"],
        "static" => ["10.0.0.100 - 10.0.0.200"],
        "cloud_properties" => {
          "name" => "net_a"
        }
      }
      make_plan(manifest)
    end

    it "should allow static ranges to be optional" do
      manifest = basic_manifest
      manifest["networks"][0]["subnets"][0] = {
        "range" => "10.0.0.0/24",
        "gateway" => "10.0.0.1",
        "dns" => ["1.2.3.4"],
        "reserved" => ["10.0.0.201 - 10.0.0.254"],
        "cloud_properties" => {
          "name" => "net_a"
        }
      }
      make_plan(manifest)
    end

    it "should allow string network ranges for static and reserved ips" do
      manifest = basic_manifest
      manifest["networks"][0]["subnets"][0] = {
        "range" => "10.0.0.0/24",
        "gateway" => "10.0.0.1",
        "dns" => ["1.2.3.4"],
        "static" => "10.0.0.100 - 10.0.0.200",
        "reserved" => "10.0.0.201 - 10.0.0.254",
        "cloud_properties" => {
          "name" => "net_a"
        }
      }

      deployment_plan = make_plan(manifest)
      network = deployment_plan.network("network_a")

      network_id = NetAddr::CIDR.create("10.0.0.0")

      network.reserve_ip(network_id.to_i + 2).should == :dynamic
      network.reserve_ip(network_id.to_i + 102).should == :static
      network.reserve_ip(network_id.to_i + 202).should be_nil
    end

    it "should not allow overlapping subnets" do
      manifest = basic_manifest
      manifest["networks"][0]["subnets"] << {
        "range" => "10.0.0.0/23",
        "gateway" => "10.0.0.1",
        "dns" => ["1.2.3.4"],
        "static" => ["10.0.0.100 - 10.0.0.200"],
        "reserved" => ["10.0.0.201 - 10.0.0.254"],
        "cloud_properties" => {
          "name" => "net_a"
        }
      }

      lambda { make_plan(manifest) }.should raise_error("overlapping subnets")
    end

    it "should not allow you to reserve the same IP twice" do
      deployment_plan = make_plan

      network = deployment_plan.network("network_a")
      network.reserve_ip("10.0.0.2").should eql(:dynamic)
      network.reserve_ip("10.0.0.100").should eql(:static)
      network.reserve_ip("10.0.0.2").should be_nil
    end


    it "should not allow you to reserve an ip outside the range" do
      manifest = basic_manifest
      manifest["networks"][0]["subnets"][0] = {
        "range" => "10.0.0.0/24",
        "gateway" => "10.0.0.1",
        "dns" => ["1.2.3.4"],
        "static" => ["10.0.0.100 - 10.0.0.200"],
        "reserved" => ["10.0.0.201 - 10.0.1.254"],
        "cloud_properties" => {
          "name" => "net_a"
        }
      }

      lambda { make_plan(manifest) }.should raise_error
    end

    it "should not allow you to reserve a gateway ip" do
      manifest = basic_manifest
      manifest["networks"][0]["subnets"][0] = {
        "range" => "10.0.0.0/24",
        "gateway" => "10.0.0.1",
        "dns" => ["1.2.3.4"],
        "static" => ["10.0.0.100 - 10.0.0.200"],
        "reserved" => ["10.0.0.1"],
        "cloud_properties" => {
          "name" => "net_a"
        }
      }

      lambda { make_plan(manifest) }.should raise_error
    end

    it "should not allow you to reserve a network id ip" do
      manifest = basic_manifest
      manifest["networks"][0]["subnets"][0] = {
        "range" => "10.0.0.0/24",
        "gateway" => "10.0.0.1",
        "dns" => ["1.2.3.4"],
        "static" => ["10.0.0.100 - 10.0.0.200"],
        "reserved" => ["10.0.0.0"],
        "cloud_properties" => {
          "name" => "net_a"
        }
      }

      lambda { make_plan(manifest) }.should raise_error
    end

    it "should not allow you to assign a static ip outside the range" do
      manifest = basic_manifest
      manifest["networks"][0]["subnets"][0] = {
        "range" => "10.0.0.0/24",
        "gateway" => "10.0.0.1",
        "dns" => ["1.2.3.4"],
        "static" => ["10.0.1.100 - 10.0.1.200"],
        "reserved" => ["10.0.0.201 - 10.0.0.254"],
        "cloud_properties" => {
          "name" => "net_a"
        }
      }

      lambda { make_plan(manifest) }.should raise_error
    end

    it "should not allow you to assign a static ip to a gateway ip" do
      manifest = basic_manifest
      manifest["networks"][0]["subnets"][0] = {
        "range" => "10.0.0.0/24",
        "gateway" => "10.0.0.1",
        "dns" => ["1.2.3.4"],
        "static" => ["10.0.0.1"],
        "reserved" => ["10.0.0.201 - 10.0.0.254"],
        "cloud_properties" => {
          "name" => "net_a"
        }
      }

      lambda { make_plan(manifest) }.should raise_error
    end

    it "should not allow you to assign a static ip to a network id ip" do
      manifest = basic_manifest
      manifest["networks"][0]["subnets"][0] = {
        "range" => "10.0.0.0/24",
        "gateway" => "10.0.0.1",
        "dns" => ["1.2.3.4"],
        "static" => ["10.0.0.0"],
        "reserved" => ["10.0.0.201 - 10.0.0.254"],
        "cloud_properties" => {
          "name" => "net_a"
        }
      }

      lambda { make_plan(manifest) }.should raise_error
    end

    it "should not allow you to assign a static ip to a reserved ip" do
      manifest = basic_manifest
      manifest["networks"][0]["subnets"][0] = {
        "range" => "10.0.0.0/24",
        "gateway" => "10.0.0.1",
        "dns" => ["1.2.3.4"],
        "static" => ["10.0.0.201"],
        "reserved" => ["10.0.0.201 - 10.0.0.254"],
        "cloud_properties" => {
          "name" => "net_a"
        }
      }

      lambda { make_plan(manifest) }.should raise_error
    end

    it "should let an instance use a valid reservation" do
      deployment_plan = make_plan
      job = deployment_plan.job("job_a")
      instance = job.instance(0)
      instance_network = instance.network("network_a")
      instance_network.reserved.should be_false
      instance_network.use_reservation("10.0.0.100", true)
      instance_network.reserved.should be_true
    end

    it "should not let an instance use a invalid reservation" do
      deployment_plan = make_plan
      job = deployment_plan.job("job_a")
      instance = job.instance(0)
      instance_network = instance.network("network_a")
      instance_network.reserved.should be_false
      instance_network.use_reservation("10.0.0.101", true)
      instance_network.reserved.should be_false
    end

    it "should not allow to reserve more IPs than available" do
      deployment_plan = make_plan
      network = deployment_plan.network("network_a")
      lambda {99.times {network.allocate_dynamic_ip}}.should raise_error("not enough dynamic IPs")
    end

    it "should allocate IPs from multiple subnets" do
      manifest = basic_manifest
      manifest["networks"][0]["subnets"] << {
        "range" => "10.0.1.0/24",
        "gateway" => "10.0.1.1",
        "dns" => ["1.2.3.4"],
        "static" => ["10.0.1.100 - 10.0.1.200"],
        "reserved" => ["10.0.1.201 - 10.0.1.254"],
        "cloud_properties" => {
          "name" => "net_b"
        }
      }

      range_a = NetAddr::CIDR.create("10.0.0.0/24")
      range_b = NetAddr::CIDR.create("10.0.1.0/24")
      counter_a = 0
      counter_b = 0

      deployment_plan = make_plan(manifest)
      network = deployment_plan.network("network_a")

      196.times do
        ip = network.allocate_dynamic_ip
        if range_a.contains?(ip)
          counter_a += 1
        elsif range_b.contains?(ip)
          counter_b += 1
        else
          raise "invalid ip: #{ip}"
        end
      end

      counter_a.should eql(98)
      counter_b.should eql(98)
    end

    it "should not allow two networks with the same canonical name" do
      manifest = basic_manifest
      network_b = manifest["networks"].first._deep_copy
      network_b["name"] = "network-a"
      manifest["networks"] << network_b

      lambda {
        make_plan(manifest)
      }.should raise_error("Invalid network name: 'network-a', canonical name already taken.")
    end

  end

  describe "Instances" do

    CURRENT_STATE = {
      "networks" => {
        "network_a" => {
          "netmask" => "255.255.255.0",
          "ip" => "10.0.0.100",
          "default" => ["dns", "gateway"],
          "gateway" => "10.0.0.1",
          "cloud_properties" => {"name" => "net_a"},
          "dns" => ["1.2.3.4"]
        }
      },
      "resource_pool" => {
        "name" => "small",
        "stemcell" => {"name" => "jeos", "version" => "1"},
        "cloud_properties" => {"ram" => "512mb", "cpu" => 1, "disk" => "2gb"}
      },
      "configuration_hash" => "config_hash",
      "packages" => {
        "test_package"=> {
          "name" => "test_package",
          "blobstore_id" => "pkg-blob-id",
          "sha1" => "pkg-sha1",
          "version" => "33.1"
        }
      },
      "persistent_disk" => 2048,
      "job" => {
        "name" => "job_a",
        "template" => "template_name",
        "version" => "1",
        "sha1" => "job-sha1",
        "blobstore_id" => "template_blob"
      },
      "job_state" => "running"
    }

    def expect_instance_changes(instance, *expected_changes)
      possible_changes = [
        :networks_changed?,
        :resource_pool_changed?,
        :configuration_changed?,
        :state_changed?,
        :packages_changed?,
        :persistent_disk_changed?,
        :job_changed?,
      ]

      expected_changes.each do |change|
        instance.should have_flag_set(change)
      end

      (possible_changes - expected_changes).each do |change|
        instance.should_not have_flag_set(change)
      end

      if expected_changes.size > 0
        instance.should have_flag_set(:changed?)
      else
        instance.should_not have_flag_set(:changed?)
      end
    end

    def tap_state
      state = CURRENT_STATE._deep_copy
      yield state if block_given?
      state
    end

    before(:each) do
      template_data = {
        :name => "template_name",
        :version => 1,
        :sha1 => "job-sha1",
        :blobstore_id => "template_blob"
      }

      @domain = Bosh::Director::Models::Dns::Domain.make
      @dns_record = Bosh::Director::Models::Dns::Record.make(:domain => @domain,
        :name => "0.job-a.network-a.test-deployment.bosh", :type => "A", :content => "10.0.0.100")

      @template = Bosh::Director::Models::Template.make(template_data)
      @package = Bosh::Director::Models::Package.make(:name => "test_package", :version => "33")

      compiled_package_data = {
        :package => @package,
        :sha1 => "pkg-sha1",
        :blobstore_id => "pkg-blob-id",
        :build => 1
      }

      @compiled_package = Bosh::Director::Models::CompiledPackage.make(compiled_package_data)

      @manifest = basic_manifest
      @deployment_plan = make_plan(@manifest)
      @job = @deployment_plan.job("job_a")
      @job.template = @template
      @instance = @job.instance(0)
      @job.add_package(@package, @compiled_package)
      @instance.configuration_hash = "config_hash"
    end

    describe "tracking changes" do
      it "tracks no change" do
        @instance.current_state = tap_state
        expect_instance_changes(@instance, *[])
      end

      it "tracks DNS change with missing DNS record" do
        @dns_record.destroy
        @instance.current_state = tap_state
        expect_instance_changes(@instance, :dns_changed?)
      end

      it "tracks DNS change with changed DNS record" do
        @dns_record.update(:content => "1.2.3.4")
        @instance.current_state = tap_state
        expect_instance_changes(@instance, :dns_changed?)
      end

      it "tracks job change" do
        @instance.current_state = tap_state do |state|
          state["job"]["blobstore_id"] = "old_blob"
        end
        expect_instance_changes(@instance, :job_changed?)
      end

      it "tracks job state (started)" do
        @instance.state = "started"
        @instance.current_state = tap_state do |state|
          state["job_state"] = "stopped"
        end
        expect_instance_changes(@instance, :state_changed?)
      end

      it "tracks job state (stopped)" do
        @instance.state = "stopped"
        @instance.current_state = tap_state do |state|
          state["job_state"] = "running"
        end
        expect_instance_changes(@instance, :state_changed?)
      end

      it "tracks networks change" do
        @instance.current_state = tap_state do |state|
          state["networks"]["network_a"]["ip"] = "10.0.0.20"
        end
        expect_instance_changes(@instance, :networks_changed?)
      end

      it "tracks resource pool change" do
        @instance.current_state = tap_state do |state|
          state["resource_pool"]["name"] = "medium"
        end
        expect_instance_changes(@instance, :resource_pool_changed?)
      end

      it "tracks configuration change" do
        @instance.current_state = tap_state do |state|
          state["configuration_hash"] = "some other hash"
        end
        expect_instance_changes(@instance, :configuration_changed?)
      end

      it "tracks packages change" do
        @instance.current_state = tap_state do |state|
          state["packages"] = {"pkg_a" => {"name" => "pkg_a", "sha1" => "a_sha1", "version" => 1}}
        end
        expect_instance_changes(@instance, :packages_changed?)
      end

      it "tracks persistent disk change" do
        @instance.current_state = tap_state do |state|
          state["persistent_disk"] = "4gb"
        end
        expect_instance_changes(@instance, :persistent_disk_changed?)
      end
    end

    it "should generate the proper apply spec" do
      @instance.spec.should eql({
        "configuration_hash" => "config_hash",
        "packages" => {
          "test_package"=> {
            "name" => "test_package",
            "blobstore_id" => "pkg-blob-id",
            "sha1" => "pkg-sha1",
            "version" => "33.1"
          }
        },
        "resource_pool" => {
          "stemcell" => {"name" => "jeos", "version" => "1"},
          "name" => "small",
          "cloud_properties" => {"ram" => "512mb", "cpu" => 1, "disk" => "2gb"}
        },
        "networks" => {
          "network_a" => {
            "netmask" => "255.255.255.0",
            "ip" => "10.0.0.100",
            "default" => ["dns", "gateway"],
            "gateway" => "10.0.0.1",
            "cloud_properties" => {"name" => "net_a"},
            "dns" => ["1.2.3.4"]
          }
        },
        "index" => 0,
        "job" => {
          "name" => "job_a",
          "template" => "template_name",
          "blobstore_id" => "template_blob",
          "sha1" => "job-sha1",
          "version" => "1",
        },
        "persistent_disk" => 2048,
        "release" => {"name" => "test_release", "version" => "1"},
        "deployment" => "test_deployment",
        "properties" => {"test" => "property"}
      })
    end

  end

  describe "Packages" do

    it "should track packages" do
      deployment_plan = make_plan
      job = deployment_plan.job("job_a")

      package_a = Bosh::Director::Models::Package.make(:name => "a", :version => "1")
      compiled_package_a = Bosh::Director::Models::CompiledPackage.make(:package => package_a,
                                                                        :build => 1,
                                                                        :blobstore_id => "blob-a",
                                                                        :sha1 => "sha1-a")

      package_b = Bosh::Director::Models::Package.make(:name => "b", :version => "2")
      compiled_package_b = Bosh::Director::Models::CompiledPackage.make(:package => package_a,
                                                                        :build => 3,
                                                                        :blobstore_id => "blob-b",
                                                                        :sha1 => "sha1-b")

      job.add_package(package_a, compiled_package_a)
      job.add_package(package_b, compiled_package_b)
      job.package_spec.should eql({"a" => {"name" => "a", "blobstore_id" => "blob-a", "sha1" => "sha1-a", "version" => "1.1"},
                                   "b" => {"name" => "b", "blobstore_id" => "blob-b", "sha1" => "sha1-b", "version" => "2.3"}})
    end

  end

  describe "Updates" do

    it "should track update failures" do
      deployment_plan = make_plan
      job = deployment_plan.job("job_a")
      job.update_errors.should eql(0)
      job.record_update_error("some error")
      job.update_errors.should eql(1)
    end

    it "should keep track of the halt flag and halt exception" do
      plan = make_plan
      job = plan.job("job_a")
      job.update_errors.should == 0
      job.record_update_error("some error")
      job.halt_exception.should be_nil

      job.should_halt?.should be_false
      job.record_update_error("error 2")
      job.update_errors.should == 2
      job.should_halt?.should be_true

      job.halt_exception.should == "error 2"
    end

    it "should set halt flag when number of failures exceeds threshold" do
      deployment_plan = make_plan
      job = deployment_plan.job("job_a")

      2.times do
        job.should_halt?.should be_false
        job.record_update_error("some error")
      end

      job.should_halt?.should be_true
    end

    it "should set halt flag when it happened during a canary" do
      deployment_plan = make_plan
      job = deployment_plan.job("job_a")
      job.should_halt?.should be_false
      job.record_update_error("some error", :canary => true)
      job.should_halt?.should be_true
    end

  end

  describe "Compilation" do

    it "should fail if network name doesn't exist" do
      manifest = basic_manifest
      compilation = manifest["compilation"]
      compilation["network"] = "network_b"

      lambda {
        make_plan(manifest)
      }.should raise_error("Compilation workers reference an unknown network: 'network_b'")
    end

  end

end
