require File.dirname(__FILE__) + '/../spec_helper'

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

  describe "Basic parsing" do

    it "should parse a deployment manifest" do
      manifest = BASIC_MANIFEST._deep_copy

      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)
      deployment_plan.name.should eql("test_deployment")
    end

    it "should parse the release spec from the deployment manifest" do
      manifest = BASIC_MANIFEST._deep_copy

      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)

      release_spec = deployment_plan.release
      release_spec.name.should eql("test_release")
      release_spec.version.should eql("1")
      release_spec.release.should be_nil
      release_spec.deployment.should eql(deployment_plan)
    end

    it "should parse the networks from the deployment manifest" do
      manifest = BASIC_MANIFEST._deep_copy

      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)

      networks = deployment_plan.networks
      networks.size.should eql(1)

      network = networks[0]
      network.should eql(deployment_plan.network("network_a"))
      network.name.should eql("network_a")
      network.deployment.should eql(deployment_plan)
    end

    it "should parse the resource pools from the deployment manifest" do
      manifest = BASIC_MANIFEST._deep_copy

      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)

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
      manifest = BASIC_MANIFEST._deep_copy

      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)

      resource_pool = deployment_plan.resource_pool("small")
      stemcell = resource_pool.stemcell

      stemcell.name.should eql("jeos")
      stemcell.version.should eql("1")
      stemcell.stemcell.should be_nil
      stemcell.resource_pool.should eql(resource_pool)
      stemcell.spec.should eql({"name" => "jeos", "version" => "1"})
    end

    it "should parse the jobs from the deployment manifest" do
      manifest = BASIC_MANIFEST._deep_copy

      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)

      jobs = deployment_plan.jobs
      jobs.size.should eql(1)

      resource_pool = deployment_plan.resource_pool("small")

      job = jobs[0]
      job.should eql(deployment_plan.job("job_a"))
      job.name.should eql("job_a")
      job.persistent_disk.should eql(2048)
      job.resource_pool.should eql(resource_pool)
      job.template.name.should eql("job_a")
      job.package_spec.should eql({})
    end

    it "should parse the instances from the deployment manifest" do
      manifest = BASIC_MANIFEST._deep_copy

      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)

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
      manifest = BASIC_MANIFEST._deep_copy

      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)

      job = deployment_plan.job("job_a")
      instance = job.instance(0)
      instance.network_settings.should eql({"network_a" => {
        "netmask" => "255.255.255.0",
        "ip" => "10.0.0.100",
        "default" => true,
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
      manifest = BASIC_MANIFEST._deep_copy

      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)

      update_settings = deployment_plan.update
      update_settings.canaries.should eql(1)
      update_settings.canary_watch_time.should eql(30000)
      update_settings.max_in_flight.should eql(5)
      update_settings.update_watch_time.should eql(10000)
      update_settings.max_errors.should eql(2)

      update_settings = deployment_plan.job("job_a").update
      update_settings.canaries.should eql(1)
      update_settings.canary_watch_time.should eql(30000)
      update_settings.max_in_flight.should eql(5)
      update_settings.update_watch_time.should eql(10000)
      update_settings.max_errors.should eql(2)
    end

    it "should parse the update settings from the deployment manifest with inheritance" do
      manifest = BASIC_MANIFEST._deep_copy
      manifest["jobs"][0]["update"] = {
        "canaries" => 2,
        "canary_watch_time" => 1000,
        "max_in_flight" => 3,
        "update_watch_time" => 500,
        "max_errors" => -1
      }

      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)

      update_settings = deployment_plan.update
      update_settings.canaries.should eql(1)
      update_settings.canary_watch_time.should eql(30000)
      update_settings.max_in_flight.should eql(5)
      update_settings.update_watch_time.should eql(10000)
      update_settings.max_errors.should eql(2)

      update_settings = deployment_plan.job("job_a").update
      update_settings.canaries.should eql(2)
      update_settings.canary_watch_time.should eql(1000)
      update_settings.max_in_flight.should eql(3)
      update_settings.update_watch_time.should eql(500)
      update_settings.max_errors.should eql(-1)
    end

    it "should parse the compilation settings from the deployment manifest" do
      manifest = BASIC_MANIFEST._deep_copy

      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)

      compilation_settings = deployment_plan.compilation
      compilation_settings.workers.should eql(2)
      compilation_settings.network.should eql(deployment_plan.network("network_a"))
      compilation_settings.cloud_properties.should eql({"ram" => "512mb", "cpu" => 1, "disk" => "2gb"})
    end

    it "should parse deployment properties" do
      manifest = BASIC_MANIFEST._deep_copy
      manifest["properties"] = {"foo" => "bar"}

      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)
      deployment_plan.properties.should eql({"foo" => "bar"})
    end

    it "should let you override properties at the job level" do
      manifest = BASIC_MANIFEST._deep_copy
      manifest["properties"] = {"foo" => "bar", "test" => {"a" => 5, "b" => 6}}
      manifest["jobs"][0]["properties"] = {"test" => {"b" => 7}}

      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)
      deployment_plan.properties.should eql({"foo" => "bar", "test" => {"a" => 5, "b" => 6}})
      deployment_plan.job("job_a").properties.should eql({"foo" => "bar", "test" => {"a" => 5, "b" => 7}})
    end

  end

  describe "Jobs" do

    it "should preserve job order" do
      manifest = BASIC_MANIFEST._deep_copy
      job = manifest["jobs"].first
      job["instances"] = 1
      job["networks"] = [{"name" => "network_a"}]

      5.times do |index|
        new_job = job._deep_copy
        new_job["name"] = "job_a_#{index}"
        manifest["jobs"] << new_job
      end

      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)
      jobs = deployment_plan.jobs
      jobs[0].name.should eql("job_a")
      jobs[1].name.should eql("job_a_0")
      jobs[2].name.should eql("job_a_1")
      jobs[3].name.should eql("job_a_2")
      jobs[4].name.should eql("job_a_3")
      jobs[5].name.should eql("job_a_4")
    end

    it "should fail when the number of instances exceeds resource pool capacity" do
      manifest = BASIC_MANIFEST._deep_copy
      manifest["jobs"].first["instances"] = 15
      lambda { Bosh::Director::DeploymentPlan.new(manifest) }.should raise_error "resource pool too small"
    end


    it "should fail if the resource pool doesn't exist" do
      manifest = BASIC_MANIFEST._deep_copy
      job = manifest["jobs"].first
      job["resource_pool"] = "bad"

      lambda {
        Bosh::Director::DeploymentPlan.new(manifest)
      }.should raise_error("Job job_a references an unknown resource pool: bad")
    end

    it "should fail if network name doesn't exist" do
      manifest = BASIC_MANIFEST._deep_copy
      job = manifest["jobs"].first

      job["networks"] = [
        {
          "name" => "network_b",
          "static_ips" => ["10.0.0.100 - 10.0.0.104"]
        }
      ]

      lambda {
        Bosh::Director::DeploymentPlan.new(manifest)
      }.should raise_error("Job job_a references an unknown network: network_b")
    end

    it "should fail if no networks were specified" do
      manifest = BASIC_MANIFEST._deep_copy
      job = manifest["jobs"].first

      job["networks"] = []

      lambda {
        Bosh::Director::DeploymentPlan.new(manifest)
      }.should raise_error("Job job_a must specify at least one network")
    end

    it "should let you set a default network" do
      manifest = BASIC_MANIFEST._deep_copy
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
        { "name" => "network_a", "default" => true },
        { "name" => "network_b" }
      ]

      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)
      deployment_plan.job("job_a").default_network.should == "network_a"
    end

    it "should automatically set the default network if there was only one network configured" do
      manifest = BASIC_MANIFEST._deep_copy
      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)
      deployment_plan.job("job_a").default_network.should == "network_a"
    end

    it "should require a default network if more than one network was configured" do
      manifest = BASIC_MANIFEST._deep_copy
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
        Bosh::Director::DeploymentPlan.new(manifest)
      }.should raise_error("Job job_a must specify a default network since it's has more than one network configured")
    end

    it "should fail if more than one default network was configured" do
      manifest = BASIC_MANIFEST._deep_copy
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
        { "name" => "network_a", "default" => true },
        { "name" => "network_b", "default" => true }
      ]

      lambda {
        Bosh::Director::DeploymentPlan.new(manifest)
      }.should raise_error("Job job_a must specify only one default network")
    end
  end

  describe "Resource pools" do

    it "should manage resource pool allocations" do
      manifest = BASIC_MANIFEST._deep_copy

      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)
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
      manifest = BASIC_MANIFEST._deep_copy

      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)
      resource_pool = deployment_plan.resource_pool("small")

      lambda {11.times {resource_pool.reserve_vm}}.should raise_error
    end

    it "should track idle vm change state (no change)" do
      manifest = BASIC_MANIFEST._deep_copy

      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)
      resource_pool = deployment_plan.resource_pool("small")

      idle_vm = resource_pool.add_idle_vm
      idle_vm.ip = NetAddr::CIDR.create("10.0.0.20").to_i
      idle_vm.vm = Bosh::Director::Models::Vm.make

      idle_vm.current_state = {
        "networks" => {
          "network_a" => {
            "netmask" => "255.255.255.0",
            "ip" => "10.0.0.20",
            "default" => true,
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
      manifest = BASIC_MANIFEST._deep_copy

      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)
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
      manifest = BASIC_MANIFEST._deep_copy

      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)
      resource_pool = deployment_plan.resource_pool("small")

      idle_vm = resource_pool.add_idle_vm
      idle_vm.ip = NetAddr::CIDR.create("10.0.0.20").to_i
      idle_vm.vm = Bosh::Director::Models::Vm.make

      idle_vm.current_state = {
        "networks" => {
          "network_a" => {
            "netmask" => "255.255.255.0",
            "ip" => "10.0.0.20",
            "default" => true,
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
      manifest = BASIC_MANIFEST._deep_copy

      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)
      resource_pool = deployment_plan.resource_pool("small")

      idle_vm = resource_pool.add_idle_vm
      idle_vm.ip = "10.0.0.50"

      idle_vm.network_settings.should == {
          "network_a" => {
            "netmask" => "255.255.255.0",
            "ip" => "10.0.0.50",
            "default" => true,
            "gateway" => "10.0.0.1",
            "cloud_properties" => {"name" => "net_a"},
            "dns" => ["1.2.3.4"]
          }
        }
    end

    it "should return the network settings for the bound instance if available" do
      manifest = BASIC_MANIFEST._deep_copy

      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)
      resource_pool = deployment_plan.resource_pool("small")

      instance_spec = mock("instance_spec")
      instance_spec.stub!(:network_settings).and_return({"network_a" => {"ip" => "foo"}})

      idle_vm = resource_pool.add_idle_vm
      idle_vm.bound_instance = instance_spec

      idle_vm.network_settings.should == {"network_a" => {"ip" => "foo"}}
    end

  end

  describe "Networks" do

    it "should manage network allocations" do
      manifest = BASIC_MANIFEST._deep_copy

      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)
      network = deployment_plan.network("network_a")

      starting_ip = NetAddr::CIDR.create("10.0.0.2")

      97.times do |index|
        network.reserve_ip(starting_ip.to_i + index)
      end

      NetAddr::CIDR.create(network.allocate_dynamic_ip).ip.should eql("10.0.0.99")
    end

    it "should allow gateways to be optional" do
      manifest = BASIC_MANIFEST._deep_copy
      manifest["networks"][0]["subnets"][0] = {
        "range" => "10.0.0.0/24",
        "dns" => ["1.2.3.4"],
        "static" => ["10.0.0.100 - 10.0.0.200"],
        "reserved" => ["10.0.0.201 - 10.0.0.254"],
        "cloud_properties" => {
          "name" => "net_a"
        }
      }
      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)
      network = deployment_plan.network("network_a")
      network.network_settings("10.0.0.2").should == {
        "netmask" => "255.255.255.0",
        "ip" => "10.0.0.2",
        "cloud_properties" => {"name" => "net_a"},
        "dns"=>["1.2.3.4"]
      }
    end

    it "should allow DNS to be optional" do
      manifest = BASIC_MANIFEST._deep_copy
      manifest["networks"][0]["subnets"][0] = {
        "range" => "10.0.0.0/24",
        "static" => ["10.0.0.100 - 10.0.0.200"],
        "reserved" => ["10.0.0.201 - 10.0.0.254"],
        "cloud_properties" => {
          "name" => "net_a"
        }
      }
      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)
      network = deployment_plan.network("network_a")
      network.network_settings("10.0.0.2").should == {
        "netmask" => "255.255.255.0",
        "ip" => "10.0.0.2",
        "cloud_properties" => {"name" => "net_a"}
      }
    end

    it "should allow string network ranges for static and reserved ips" do
      manifest = BASIC_MANIFEST._deep_copy
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

      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)
      network = deployment_plan.network("network_a")

      network_id = NetAddr::CIDR.create("10.0.0.0")

      network.reserve_ip(network_id.to_i + 2).should == :dynamic
      network.reserve_ip(network_id.to_i + 102).should == :static
      network.reserve_ip(network_id.to_i + 202).should be_nil
    end

    it "should not allow overlapping subnets" do
      manifest = BASIC_MANIFEST._deep_copy
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

      lambda {Bosh::Director::DeploymentPlan.new(manifest)}.should raise_error("overlapping subnets")
    end

    it "should not allow you to reserve the same IP twice" do
      manifest = BASIC_MANIFEST._deep_copy
      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)

      network = deployment_plan.network("network_a")
      network.reserve_ip("10.0.0.2").should eql(:dynamic)
      network.reserve_ip("10.0.0.100").should eql(:static)
      network.reserve_ip("10.0.0.2").should be_nil
    end


    it "should not allow you to reserve an ip outside the range" do
      manifest = BASIC_MANIFEST._deep_copy
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

      lambda {Bosh::Director::DeploymentPlan.new(manifest)}.should raise_error
    end

    it "should not allow you to reserve a gateway ip" do
      manifest = BASIC_MANIFEST._deep_copy
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

      lambda {Bosh::Director::DeploymentPlan.new(manifest)}.should raise_error
    end

    it "should not allow you to reserve a network id ip" do
      manifest = BASIC_MANIFEST._deep_copy
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

      lambda {Bosh::Director::DeploymentPlan.new(manifest)}.should raise_error
    end

    it "should not allow you to assign a static ip outside the range" do
      manifest = BASIC_MANIFEST._deep_copy
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

      lambda {Bosh::Director::DeploymentPlan.new(manifest)}.should raise_error
    end

    it "should not allow you to assign a static ip to a gateway ip" do
      manifest = BASIC_MANIFEST._deep_copy
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

      lambda {Bosh::Director::DeploymentPlan.new(manifest)}.should raise_error
    end

    it "should not allow you to assign a static ip to a network id ip" do
      manifest = BASIC_MANIFEST._deep_copy
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

      lambda {Bosh::Director::DeploymentPlan.new(manifest)}.should raise_error
    end

    it "should not allow you to assign a static ip to a reserved ip" do
      manifest = BASIC_MANIFEST._deep_copy
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

      lambda {Bosh::Director::DeploymentPlan.new(manifest)}.should raise_error
    end

    it "should let an instance use a valid reservation" do
      manifest = BASIC_MANIFEST._deep_copy
      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)
      job = deployment_plan.job("job_a")
      instance = job.instance(0)
      instance_network = instance.network("network_a")
      instance_network.reserved.should be_false
      instance_network.use_reservation("10.0.0.100", true)
      instance_network.reserved.should be_true
    end

    it "should not let an instance use a invalid reservation" do
      manifest = BASIC_MANIFEST._deep_copy
      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)
      job = deployment_plan.job("job_a")
      instance = job.instance(0)
      instance_network = instance.network("network_a")
      instance_network.reserved.should be_false
      instance_network.use_reservation("10.0.0.101", true)
      instance_network.reserved.should be_false
    end

    it "should not allow to reserve more IPs than available" do
      manifest = BASIC_MANIFEST._deep_copy
      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)
      network = deployment_plan.network("network_a")
      lambda {99.times {network.allocate_dynamic_ip}}.should raise_error("not enough dynamic IPs")
    end

    it "should allocate IPs from multiple subnets" do
      manifest = BASIC_MANIFEST._deep_copy
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

      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)
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

  end

  describe "Instances" do

    CURRENT_STATE = {
      "networks" => {
        "network_a" => {
          "netmask" => "255.255.255.0",
          "ip" => "10.0.0.100",
          "default" => true,
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
      "job" => {"name" => "job_a", "version" => "1", "sha1" => "job-sha1", "blobstore_id" => "template_blob"}
    }

    before(:each) do
      @template = Bosh::Director::Models::Template.make(:version => 1,
                                                        :sha1 => "job-sha1",
                                                        :blobstore_id => "template_blob")
      @package = Bosh::Director::Models::Package.make(:name => "test_package", :version => "33")
      @compiled_package = Bosh::Director::Models::CompiledPackage.make(:package => @package,
                                                                       :sha1 => "pkg-sha1",
                                                                       :blobstore_id => "pkg-blob-id",
                                                                       :build => 1)

      @manifest = BASIC_MANIFEST._deep_copy
      @deployment_plan = Bosh::Director::DeploymentPlan.new(@manifest)
      @job = @deployment_plan.job("job_a")
      @job.template = @template
      @instance = @job.instance(0)
      @job.add_package(@package, @compiled_package)
      @instance.configuration_hash = "config_hash"
    end

    it "should track instance changes compared to the current state (no change)" do
      @instance.current_state = CURRENT_STATE._deep_copy

      @instance.networks_changed?.should be_false
      @instance.resource_pool_changed?.should be_false
      @instance.configuration_changed?.should be_false
      @instance.packages_changed?.should be_false
      @instance.persistent_disk_changed?.should be_false
      @instance.job_changed?.should be_false
      @instance.changed?.should be_false
    end

    it "should track instance changes compared to the current state (job change)" do
      current_state = CURRENT_STATE._deep_copy
      current_state["job"]["blobstore_id"] = "old_blob"
      @instance.current_state = current_state

      @instance.networks_changed?.should be_false
      @instance.resource_pool_changed?.should be_false
      @instance.configuration_changed?.should be_false
      @instance.packages_changed?.should be_false
      @instance.persistent_disk_changed?.should be_false
      @instance.job_changed?.should be_true
      @instance.changed?.should be_true
    end

    it "should track instance changes compared to the current state (networks change)" do
      current_state = CURRENT_STATE._deep_copy
      current_state["networks"]["network_a"]["ip"] = "10.0.0.20"
      @instance.current_state = current_state

      @instance.networks_changed?.should be_true
      @instance.resource_pool_changed?.should be_false
      @instance.configuration_changed?.should be_false
      @instance.packages_changed?.should be_false
      @instance.persistent_disk_changed?.should be_false
      @instance.job_changed?.should be_false
      @instance.changed?.should be_true
    end

    it "should track instance changes compared to the current state (resource pool change)" do
      current_state = CURRENT_STATE._deep_copy
      current_state["resource_pool"]["name"] = "medium"
      @instance.current_state = current_state

      @instance.networks_changed?.should be_false
      @instance.resource_pool_changed?.should be_true
      @instance.configuration_changed?.should be_false
      @instance.packages_changed?.should be_false
      @instance.persistent_disk_changed?.should be_false
      @instance.job_changed?.should be_false
      @instance.changed?.should be_true
    end

    it "should track instance changes compared to the current state (configuration change)" do
      current_state = CURRENT_STATE._deep_copy
      current_state["configuration_hash"] = "some other hash"
      @instance.current_state = current_state

      @instance.networks_changed?.should be_false
      @instance.resource_pool_changed?.should be_false
      @instance.configuration_changed?.should be_true
      @instance.packages_changed?.should be_false
      @instance.persistent_disk_changed?.should be_false
      @instance.job_changed?.should be_false
      @instance.changed?.should be_true
    end

    it "should track instance changes compared to the current state (packages change)" do
      current_state = CURRENT_STATE._deep_copy
      current_state["packages"] = {"pkg_a" => {"name" => "pkg_a", "sha1" => "a_sha1", "version" => 1}}
      @instance.current_state = current_state

      @instance.networks_changed?.should be_false
      @instance.resource_pool_changed?.should be_false
      @instance.configuration_changed?.should be_false
      @instance.packages_changed?.should be_true
      @instance.persistent_disk_changed?.should be_false
      @instance.job_changed?.should be_false
      @instance.changed?.should be_true
    end

    it "should track instance changes compared to the current state (disk change)" do
      current_state = CURRENT_STATE._deep_copy
      current_state["persistent_disk"] = "4gb"
      @instance.current_state = current_state

      @instance.networks_changed?.should be_false
      @instance.resource_pool_changed?.should be_false
      @instance.configuration_changed?.should be_false
      @instance.packages_changed?.should be_false
      @instance.persistent_disk_changed?.should be_true
      @instance.job_changed?.should be_false
      @instance.changed?.should be_true
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
            "default" => true,
            "gateway" => "10.0.0.1",
            "cloud_properties" => {"name" => "net_a"},
            "dns" => ["1.2.3.4"]
          }
        },
        "index" => 0,
        "job" => {"name" => "job_a", "blobstore_id" => "template_blob", "sha1" => "job-sha1", "version" => "1"},
        "persistent_disk" => 2048,
        "release" => {"name" => "test_release", "version" => "1"},
        "deployment" => "test_deployment",
        "properties" => {"test" => "property"}
      })
    end

  end

  describe "Packages" do

    it "should track packages" do
      manifest = BASIC_MANIFEST._deep_copy
      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)
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
      manifest = BASIC_MANIFEST._deep_copy
      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)
      job = deployment_plan.job("job_a")
      job.update_errors.should eql(0)
      job.record_update_error("some error")
      job.update_errors.should eql(1)
    end

    it "should issue a rollback when number of failures exceeds threshold" do
      manifest = BASIC_MANIFEST._deep_copy
      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)
      job = deployment_plan.job("job_a")

      3.times do
        job.should_rollback?.should be_false
        job.record_update_error("some error")
      end

      job.should_rollback?.should be_true
    end

    it "should issue a rollback when it happened during a canary" do
      manifest = BASIC_MANIFEST._deep_copy
      deployment_plan = Bosh::Director::DeploymentPlan.new(manifest)
      job = deployment_plan.job("job_a")
      job.should_rollback?.should be_false
      job.record_update_error("some error", :canary => true)
      job.should_rollback?.should be_true
    end

  end

end
