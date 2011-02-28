require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Director::DeploymentPlanCompiler do

  IP_10_0_0_5 = 167772165

  describe "bind_existing_deployment" do

    BASIC_STATE = {
      "deployment" => "test_deployment",
      "job" => {"name" => "test_job", "blobstore_id" => "job_blob"},
      "index" => 5,
      "configuration_hash" => "config_hash",
      "packages" => {
        "test_package" => {"version" => "1"}
      },
      "persistent_disk" => 1024,
      "resource_pool" => {
        "stemcell" => {
          "name" => "ubuntu",
          "network" => "network-a",
          "version" => 3
        },
        "name" => "test_resource_pool",
        "cloud_properties" => {
          "ram" => "2GB",
          "disk" => "10GB",
          "cores" => 2
        }
      },
      "networks" => {
        "network-a" => {
          "netmask" => "255.255.255.0",
          "gw" => "10.0.0.1",
          "ip" => "10.0.0.5",
          "cloud_properties" => {"name" => "network-a"},
          "dns" => ["1.2.3.4"]
        }
      },
      "properties" => {"key" => "value"}
    }

    before(:each) do
      @deployment = Bosh::Director::Models::Deployment.make(:name => "test_deployment")
      @vm = Bosh::Director::Models::Vm.make(:deployment => @deployment, :agent_id => "agent-1")
      @instance = Bosh::Director::Models::Instance.make(:deployment => @deployment,
                                                        :vm => @vm,
                                                        :job => "test_job",
                                                        :index => 5)

      @deployment_plan = mock("deployment_plan")
      @agent = mock("agent")
      @job_spec = mock("job_spec")
      @resource_pool_spec = mock("resource_pool_spec")
      @stemcell_spec = mock("stemcell_spec")
      @instance_spec = mock("instance_spec")
      @network_spec = mock("network_spec")
      @instance_network_spec = mock("instance_network_spec")

      @deployment_plan.stub!(:deployment).and_return(@deployment)
      @deployment_plan.stub!(:job).with("test_job").and_return(@job_spec)
      @deployment_plan.stub!(:network).with("network-a").and_return(@network_spec)
      @deployment_plan.stub!(:resource_pool).with("test_resource_pool").and_return(@resource_pool_spec)

      @job_spec.stub!(:instance).with(5).and_return(@instance_spec)
      @job_spec.stub!(:resource_pool).and_return(@resource_pool_spec)

      @instance_spec.stub!(:job).and_return(@job_spec)
      @instance_spec.stub!(:networks).and_return([@instance_network_spec])

      @instance_network_spec.stub!(:name).and_return("network-a")
      @resource_pool_spec.stub!(:stemcell).and_return(@stemcell_spec)
      @resource_pool_spec.stub!(:network).and_return(@network_spec)
      @network_spec.stub!(:name).and_return("network-a")

      Bosh::Director::AgentClient.stub!(:new).with("agent-1").and_return(@agent)
      Bosh::Director::Config.stub!(:cloud).and_return(nil)

      @deployment_plan_compiler = Bosh::Director::DeploymentPlanCompiler.new(@deployment_plan)
    end

    it "should bind the valid resources" do
      state = BASIC_STATE._deep_copy
      @agent.stub!(:get_state).and_return(state)

      @network_spec.should_receive(:reserve_ip).with(IP_10_0_0_5).and_return(:static)
      @instance_spec.should_receive(:instance=).with(@instance)
      @instance_spec.should_receive(:current_state=).with(state)
      @instance_network_spec.should_receive(:use_reservation).with(IP_10_0_0_5, true)
      @resource_pool_spec.should_receive(:mark_allocated_vm)

      @deployment_plan_compiler.bind_existing_deployment
    end

    it "should not bind invalid networks" do
      state = BASIC_STATE._deep_copy
      @agent.stub!(:get_state).and_return(state)

      @network_spec.should_receive(:reserve_ip).with(IP_10_0_0_5).and_return(nil)
      @instance_spec.should_receive(:instance=).with(@instance)
      @instance_spec.should_receive(:current_state=).with(state)
      @instance_network_spec.should_not_receive(:use_reservation)
      @resource_pool_spec.should_receive(:mark_allocated_vm)

      @deployment_plan_compiler.bind_existing_deployment
    end

    it "should add it to the idle pool if there is no instance" do
      state = BASIC_STATE._deep_copy
      state.delete("job")
      state.delete("index")
      state.delete("configuration_hash")
      state.delete("packages")
      state.delete("persistent_disk")
      state.delete("properties")

      @instance.destroy

      @agent.stub!(:get_state).and_return(state)
      @network_spec.should_receive(:reserve_ip).with(IP_10_0_0_5).and_return(:dynamic)

      idle_vm = mock("idle_vm")
      @resource_pool_spec.should_receive(:add_idle_vm).and_return(idle_vm)
      idle_vm.should_receive(:vm=).with(@vm)
      idle_vm.should_receive(:current_state=).with(state)
      idle_vm.should_receive(:ip=).with(IP_10_0_0_5)

      @deployment_plan_compiler.bind_existing_deployment
    end

    it "should delete the VM if it's idle and the resource pool doesn't exist" do
      state = BASIC_STATE._deep_copy
      state.delete("job")
      state.delete("index")
      state.delete("configuration_hash")
      state.delete("packages")
      state.delete("persistent_disk")
      state.delete("properties")
      state["resource_pool"]["name"] = "unknown_resource_pool"

      @instance.destroy

      @agent.stub!(:get_state).and_return(state)

      @network_spec.should_receive(:reserve_ip).with(IP_10_0_0_5).and_return(:dynamic)
      @deployment_plan.stub!(:resource_pool).with("unknown_resource_pool").and_return(nil)
      @deployment_plan.should_receive(:delete_vm).with(@vm)

      @deployment_plan_compiler.bind_existing_deployment
    end

    it "should mark the VM for deletion if it's no longer needed" do
      @instance.update(:index => 6)
      @job_spec.stub!(:instance).with(6).and_return(nil)

      state = BASIC_STATE._deep_copy
      state["index"] = 6
      @agent.stub!(:get_state).and_return(state)

      @network_spec.should_receive(:reserve_ip).with(IP_10_0_0_5).and_return(:dynamic)
      @deployment_plan.should_receive(:delete_instance).with(@instance)

      @deployment_plan_compiler.bind_existing_deployment
    end

    it "should abort if the agent state and director state are out of sync (index)" do
      state = BASIC_STATE._deep_copy
      state["index"] = 1
      @agent.stub!(:get_state).and_return(state)

      Bosh::Director::Models::Vm.stub!(:find).with(:deployment_id => 1).and_return([@vm])
      Bosh::Director::Models::Instance.stub!(:find).with(:vm_id => 2).and_return([@instance])

      lambda {@deployment_plan_compiler.bind_existing_deployment}.should raise_error
    end

    it "should abort if the agent state and director state are out of sync (job)" do
      state = BASIC_STATE._deep_copy
      state["job"] = "unknown_job"
      @agent.stub!(:get_state).and_return(state)

      Bosh::Director::Models::Vm.stub!(:find).with(:deployment_id => 1).and_return([@vm])
      Bosh::Director::Models::Instance.stub!(:find).with(:vm_id => 2).and_return([@instance])

      lambda {@deployment_plan_compiler.bind_existing_deployment}.should raise_error
    end

    it "should abort if the agent state and director state are out of sync (deployment)" do
      state = BASIC_STATE._deep_copy
      state["deployment"] = "unknown_deployment"
      @agent.stub!(:get_state).and_return(state)

      Bosh::Director::Models::Vm.stub!(:find).with(:deployment_id => 1).and_return([@vm])
      Bosh::Director::Models::Instance.stub!(:find).with(:vm_id => 2).and_return([@instance])

      lambda {@deployment_plan_compiler.bind_existing_deployment}.should raise_error
    end

  end

  describe "bind_resource_pools" do

    before(:each) do
      @deployment_plan = mock("deployment_plan")
      @resource_pool_spec = mock("resource_pool_spec")
      @stemcell_spec = mock("stemcell_spec")
      @network_spec = mock("network_spec")

      @deployment_plan.stub!(:network).with("network-a").and_return(@network_spec)
      @deployment_plan.stub!(:resource_pool).with("test_resource_pool").and_return(@resource_pool_spec)
      @deployment_plan.stub!(:resource_pools).and_return([@resource_pool_spec])

      @resource_pool_spec.stub!(:stemcell).and_return(@stemcell_spec)
      @resource_pool_spec.stub!(:network).and_return(@network_spec)

      @network_spec.stub!(:name).and_return("network-a")

      Bosh::Director::Config.stub!(:cloud).and_return(nil)

      @deployment_plan_compiler = Bosh::Director::DeploymentPlanCompiler.new(@deployment_plan)
    end

    it "should do nothing when all the VMs have been allocated" do
      @resource_pool_spec.stub!(:unallocated_vms).and_return(0)
      @deployment_plan_compiler.bind_resource_pools
    end

    it "should preallocate idle vms that currently don't exist" do
      idle_vm_1 = mock("idle_vm_1")
      idle_vm_2 = mock("idle_vm_2")

      @resource_pool_spec.stub!(:unallocated_vms).and_return(2)
      @resource_pool_spec.should_receive(:add_idle_vm).and_return(idle_vm_1, idle_vm_2)
      @network_spec.should_receive(:allocate_dynamic_ip).and_return(5,25)
      idle_vm_1.should_receive(:ip=).with(5)
      idle_vm_2.should_receive(:ip=).with(25)

      @deployment_plan_compiler.bind_resource_pools
    end

  end

  describe "bind_configuration" do

    before(:each) do
      @deployment_plan = mock("deployment_plan")
      @job_spec = mock("job_spec")
      @deployment_plan.stub!(:jobs).and_return([@job_spec])

      Bosh::Director::Config.stub!(:cloud).and_return(nil)

      @deployment_plan_compiler = Bosh::Director::DeploymentPlanCompiler.new(@deployment_plan)
    end

    it "should bind the configuration hash" do
      configuration_hasher = mock("configuration_hasher")
      configuration_hasher.should_receive(:hash)
      Bosh::Director::ConfigurationHasher.stub!(:new).with(@job_spec).and_return(configuration_hasher)
      @deployment_plan_compiler.bind_configuration
    end

  end

  describe "bind_instance_networks" do

    before(:each) do
      @deployment_plan = mock("deployment_plan")
      @job_spec = mock("job_spec")
      @instance_spec = mock("instance_spec")
      @network_spec = mock("network_spec")
      @instance_network_spec = mock("instance_network_spec")

      @deployment_plan.stub!(:jobs).and_return([@job_spec])
      @deployment_plan.stub!(:network).with("network-a").and_return(@network_spec)

      @job_spec.stub!(:instances).and_return([@instance_spec])

      @instance_spec.stub!(:networks).and_return([@instance_network_spec])

      @instance_network_spec.stub!(:name).and_return("network-a")

      Bosh::Director::Config.stub!(:cloud).and_return(nil)

      @deployment_plan_compiler = Bosh::Director::DeploymentPlanCompiler.new(@deployment_plan)
    end

    it "should do nothing if the ip is already reserved" do
      @instance_network_spec.stub!(:reserved).and_return(true)
      @deployment_plan_compiler.bind_instance_networks
    end

    it "should reserve a static ip" do
      @instance_network_spec.stub!(:reserved).and_return(false)
      @instance_network_spec.stub!(:ip).and_return(IP_10_0_0_5)
      @network_spec.should_receive(:reserve_ip).with(IP_10_0_0_5).and_return(:static)
      @instance_network_spec.should_receive(:use_reservation).with(IP_10_0_0_5, true)
      @deployment_plan_compiler.bind_instance_networks
    end

    it "should acquire a dynamic ip" do
      @instance_network_spec.stub!(:reserved).and_return(false)
      @instance_network_spec.stub!(:ip).and_return(nil)
      @network_spec.should_receive(:allocate_dynamic_ip).and_return(1)
      @instance_network_spec.should_receive(:use_reservation).with(1, false)
      @deployment_plan_compiler.bind_instance_networks
    end

    it "should fail reserving a static ip that was not in a static range" do
      @instance_network_spec.stub!(:reserved).and_return(false)
      @instance_network_spec.stub!(:ip).and_return(IP_10_0_0_5)
      @network_spec.should_receive(:reserve_ip).with(IP_10_0_0_5).and_return(:dynamic)
      lambda {@deployment_plan_compiler.bind_instance_networks}.should raise_error
    end

  end

  describe "bind_templates" do

    before(:each) do
      @deployment = Bosh::Director::Models::Deployment.make
      @release = Bosh::Director::Models::Release.make
      @release_version = Bosh::Director::Models::ReleaseVersion.make(:release => @release)
      @template = Bosh::Director::Models::Template.make(:release => @release, :name => "test_template")
      @template.package_names = ["test_package"]
      @template.save
      @release_version.add_template(@template)
      @package = Bosh::Director::Models::Package.make(:release => @release, :name => "test_package")
      @release_version.add_package(@package)

      @deployment_plan = mock("deployment_plan")
      @job_spec = mock("job_spec")
      @template_spec = mock("template_spec")
      @release_spec = mock("release_spec")

      @template_spec.stub!(:name).and_return("test_template")

      @deployment_plan.stub!(:templates).and_return([@template_spec])
      @deployment_plan.stub!(:release).and_return(@release_spec)

      @release_spec.stub!(:release_version).and_return(@release_version)

      Bosh::Director::Config.stub!(:cloud).and_return(nil)

      @deployment_plan_compiler = Bosh::Director::DeploymentPlanCompiler.new(@deployment_plan)
    end

    it "should bind the compiled packages to the job" do
      @template_spec.should_receive(:template=).with(@template)
      @template_spec.should_receive(:packages=).with([@package])
      @deployment_plan_compiler.bind_templates
    end
  end

  describe "bind_unallocated_vms" do
    before(:each) do
      @deployment = Bosh::Director::Models::Deployment.make
      @vm = Bosh::Director::Models::Vm.make(:deployment => @deployment)
      @instance = Bosh::Director::Models::Instance.make(:deployment => @deployment,
                                                        :vm => nil,
                                                        :job => "test_job",
                                                        :index => 5)

      @deployment_plan = mock("deployment_plan")
      @job_spec = mock("job_spec")
      @resource_pool_spec = mock("resource_pool_spec")
      @instance_spec = mock("instance_spec")
      @release_spec = mock("release_spec")
      @network_spec = mock("network_spec")

      @deployment_plan.stub!(:deployment).and_return(@deployment)
      @deployment_plan.stub!(:jobs).and_return([@job_spec])
      @deployment_plan.stub!(:release).and_return(@release_spec)

      @release_spec.stub!(:spec).and_return({"name" => "test_release", "version" => 23})

      @network_spec.stub!(:name).and_return("network-a")

      @resource_pool_spec.stub!(:network).and_return(@network_spec)

      @job_spec.stub!(:resource_pool).and_return(@resource_pool_spec)
      @job_spec.stub!(:instances).and_return([@instance_spec])
      @job_spec.stub!(:name).and_return("test_job")
      @job_spec.stub!(:spec).and_return({"name" => "test_job", "blobstore_id" => "blob"})

      @instance_spec.stub!(:job).and_return(@job_spec)
      @instance_spec.stub!(:index).and_return(5)

      Bosh::Director::Config.stub!(:cloud).and_return(nil)

      @deployment_plan_compiler = Bosh::Director::DeploymentPlanCompiler.new(@deployment_plan)
    end

    it "should late bind instance if the instance was not attached to a VM" do
      idle_vm = mock("idle_vm")
      idle_vm.stub!(:vm).and_return(@vm)
      idle_vm.stub!(:resource_pool).and_return(@resource_pool_spec)

      @instance_spec.should_receive(:network).with("network-a").and_return(nil)
      @instance_spec.should_receive(:instance).and_return(nil)
      @instance_spec.should_receive(:instance=).with(@instance)
      @instance_spec.should_receive(:idle_vm=).with(idle_vm)

      @resource_pool_spec.should_receive(:allocate_vm).and_return(idle_vm)

      @deployment_plan_compiler.bind_unallocated_vms
    end

    it "should create a new instance model when needed" do
      @instance.destroy
      idle_vm = mock("idle_vm")
      idle_vm.stub!(:vm).and_return(@vm)
      idle_vm.stub!(:resource_pool).and_return(@resource_pool_spec)

      @instance_spec.should_receive(:network).with("network-a").and_return(nil)
      @instance_spec.should_receive(:instance).and_return(nil)
      @instance_spec.should_receive(:instance=).with do |instance|
        instance.deployment.should == @deployment
        instance.job.should == "test_job"
        instance.index.should == 5
        true
      end
      @instance_spec.should_receive(:idle_vm=).with(idle_vm)

      @resource_pool_spec.should_receive(:allocate_vm).and_return(idle_vm)

      @deployment_plan_compiler.bind_unallocated_vms
    end

    it "should reuse the IP of a running VM if it has the proper network" do
      instance_network = mock("instance_network")
      idle_vm = mock("idle_vm")
      idle_vm.stub!(:vm).and_return(@vm)
      idle_vm.stub!(:ip).and_return(IP_10_0_0_5)
      idle_vm.stub!(:resource_pool).and_return(@resource_pool_spec)

      @instance_spec.should_receive(:network).with("network-a").and_return(instance_network)
      @instance_spec.should_receive(:instance).and_return(nil)
      @instance_spec.should_receive(:instance=).with(@instance)
      @instance_spec.should_receive(:idle_vm=).with(idle_vm)

      instance_network.should_receive(:use_reservation).with(IP_10_0_0_5, false)

      @resource_pool_spec.should_receive(:allocate_vm).and_return(idle_vm)

      idle_vm.should_not_receive(:bound_instance=)

      @deployment_plan_compiler.bind_unallocated_vms
    end

    it "should bind the instance to the idle VM if it's not allocated and release the existing IP reservation" do
      idle_vm = mock("idle_vm")
      idle_vm.stub!(:vm).and_return(nil)
      idle_vm.stub!(:ip).and_return(IP_10_0_0_5)
      idle_vm.stub!(:resource_pool).and_return(@resource_pool_spec)

      @instance_spec.should_receive(:instance).and_return(nil)
      @instance_spec.should_receive(:instance=).with(@instance)
      @instance_spec.should_receive(:idle_vm=).with(idle_vm)

      idle_vm.should_receive(:bound_instance=).with(@instance_spec)
      idle_vm.should_receive(:ip=).with(nil)
      @network_spec.should_receive(:release_dynamic_ip).with(IP_10_0_0_5)

      @resource_pool_spec.should_receive(:allocate_vm).and_return(idle_vm)

      @deployment_plan_compiler.bind_unallocated_vms
    end
  end

  describe "bind_instance_vms" do

    before(:each) do
      @deployment = Bosh::Director::Models::Deployment.make
      @vm = Bosh::Director::Models::Vm.make(:deployment => @deployment)
      @instance = Bosh::Director::Models::Instance.make(:deployment => @deployment,
                                                        :vm => nil,
                                                        :job => "test_job",
                                                        :index => 5)

      @deployment_plan = mock("deployment_plan")
      @job_spec = mock("job_spec")
      @resource_pool_spec = mock("resource_pool_spec")
      @instance_spec = mock("instance_spec")
      @release_spec = mock("release_spec")
      @idle_vm = mock("idle_vm")

      @deployment_plan.stub!(:deployment).and_return(@deployment)
      @deployment_plan.stub!(:jobs).and_return([@job_spec])
      @deployment_plan.stub!(:release).and_return(@release_spec)

      @release_spec.stub!(:spec).and_return({"name" => "test_release", "version" => 23})

      @job_spec.stub!(:resource_pool).and_return(@resource_pool_spec)
      @job_spec.stub!(:instances).and_return([@instance_spec])
      @job_spec.stub!(:name).and_return("test_job")
      @job_spec.stub!(:spec).and_return({"name" => "test_job", "blobstore_id" => "blob"})

      @instance_spec.stub!(:instance).and_return(@instance)
      @instance_spec.stub!(:job).and_return(@job_spec)
      @instance_spec.stub!(:index).and_return(5)

      @idle_vm.stub!(:current_state).and_return({"deployment" => "test_deployment"})
      @idle_vm.stub!(:vm).and_return(@vm)

      Bosh::Director::Config.stub!(:cloud).and_return(nil)

      @deployment_plan_compiler = Bosh::Director::DeploymentPlanCompiler.new(@deployment_plan)
    end

    it "should do nothing when all the instances already have VMs" do
      @instance.update(:vm => @vm)
      @instance_spec.should_receive(:instance).and_return(@instance)
      @deployment_plan_compiler.bind_instance_vms
    end

    it "should set the instance VM if it's missing" do
      @vm.update(:agent_id => "test_id")

      agent = mock("agent")
      agent.should_receive(:apply).and_return({
        "id" => "task-1",
        "state" => "done"
      })
      Bosh::Director::AgentClient.stub!(:new).with("test_id").and_return(agent)

      @instance_spec.stub!(:idle_vm).and_return(@idle_vm)
      @instance_spec.stub!(:current_state=)
      @deployment_plan_compiler.bind_instance_vms
      @instance.refresh
      @instance.vm.should == @vm
    end

    it "should assign the job/index/release to the VM if was missing" do
      @vm.update(:agent_id => "test_id")

      agent = mock("agent")
      agent.should_receive(:apply).with({
        "index" => 5,
        "job" => {"name" => "test_job", "blobstore_id" => "blob"},
        "deployment" => "test_deployment",
        "release" => {"name" => "test_release", "version" => 23}
      }).and_return({
        "id" => "task-1",
        "state" => "done"
      })
      Bosh::Director::AgentClient.stub!(:new).with("test_id").and_return(agent)

      @instance_spec.stub!(:idle_vm).and_return(@idle_vm)
      @instance_spec.should_receive(:current_state=).with({
        "index" => 5,
        "job" => {"name" => "test_job", "blobstore_id" => "blob"},
        "deployment" => "test_deployment",
        "release" => {"name" => "test_release", "version" => 23}
      })
      @deployment_plan_compiler.bind_instance_vms
    end
  end

  describe "delete_unneeded_vms" do

    it "should delete unneeded vms" do
      deployment_plan = mock("deployment_plan")
      cloud = mock("cloud")
      vm = Bosh::Director::Models::Vm.make

      Bosh::Director::Config.stub!(:cloud).and_return(cloud)

      vm.stub!(:cid).and_return("vm-cid")
      vm.should_receive(:delete)

      deployment_plan.stub!(:unneeded_vms).and_return([vm])

      cloud.should_receive(:delete_vm).with("vm-cid")

      deployment_plan_compiler = Bosh::Director::DeploymentPlanCompiler.new(deployment_plan)
      deployment_plan_compiler.delete_unneeded_vms
    end

  end

  describe "delete_unneeded_instances" do
    it "should delete unneeded instances" do
      deployment_plan = mock("deployment_plan")
      cloud = mock("cloud")
      instance = Bosh::Director::Models::Instance.make
      vm = Bosh::Director::Models::Vm.make
      agent = mock("agent")

      Bosh::Director::Config.stub!(:cloud).and_return(cloud)

      instance.stub!(:vm).and_return(vm)
      instance.stub!(:disk_cid).and_return("disk-cid")
      instance.should_receive(:delete)

      vm.stub!(:cid).and_return("vm-cid")
      vm.stub!(:agent_id).and_return("agent-id")
      vm.should_receive(:delete)

      agent.should_receive(:drain).and_return(0.01)
      agent.should_receive(:stop)

      Bosh::Director::AgentClient.stub!(:new).with("agent-id").and_return(agent, nil)

      deployment_plan.stub!(:unneeded_instances).and_return([instance])

      cloud.should_receive(:delete_vm).with("vm-cid")
      cloud.should_receive(:delete_disk).with("disk-cid")

      deployment_plan_compiler = Bosh::Director::DeploymentPlanCompiler.new(deployment_plan)
      deployment_plan_compiler.delete_unneeded_instances
    end
  end

end