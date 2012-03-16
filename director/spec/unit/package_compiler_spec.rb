# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::PackageCompiler do
  before(:each) do
    @task = stub(:CompileTask)
    @package = BD::Models::Package.make(
        :name => "gcc", :version => "1.2", :blobstore_id => "blob-1",
        :sha1 => "sha-1")
    @stemcell = BD::Models::Stemcell.make(:name => "linux", :version => "3.4.5")
    @task.stub(:package).and_return(@package)
    @task.stub(:stemcell).and_return(@stemcell)

    @cloud = stub(:Cloud)
    BD::Config.stub(:cloud).and_return(@cloud)

    @network = stub(:NetworkSpec)
    @network.stub(:name).and_return("my-net")
    @compilation_config = stub(:CompilationConfig)
    @compilation_config.stub(:cloud_properties).and_return({"foo" => "bar"})
    @compilation_config.stub(:env).and_return({"env" => "baz"})
    @compilation_config.stub(:workers).and_return(3)
    @compilation_config.stub(:network).and_return(@network)
    @compilation_config.stub(:reuse_compilation_vms).and_return(false)
    @deployment = BD::Models::Deployment.make
    @deployment_plan = stub(:DeploymentPlan)
    @deployment_plan.stub(:compilation).and_return(@compilation_config)
    @deployment_plan.stub(:deployment).and_return(@deployment)

    @package_compiler = BD::PackageCompiler.new(@deployment_plan)
  end

  describe :compile do
    it "should do nothing if everything is compiled" do
      @package_compiler.should_receive(:generate_compile_tasks)
      @package_compiler.should_receive(:generate_reverse_dependencies)

      @task.stub(:ready_to_compile?).and_return(false)
      @package_compiler.compile_tasks = {"key" => @task}

      @package_compiler.compile
    end

    it "should compile packages" do
      @package_compiler.should_receive(:generate_compile_tasks)
      @package_compiler.should_receive(:generate_reverse_dependencies)

      @task.stub(:ready_to_compile?).and_return(true)
      @package_compiler.compile_tasks = {"key" => @task}
      @package_compiler.should_receive(:reserve_networks)
      @package_compiler.should_receive(:compile_packages)
      @package_compiler.should_receive(:release_networks)

      @package_compiler.compile
    end
  end

  describe :compile_packages do
    def create_task(ready)
      task = stub(:CompileTask)
      task.stub(:compiled_package).and_return(nil)
      task.stub(:ready_to_compile?).and_return(ready)
      task
    end

    it "should schedule ready tasks" do
      tasks = {"a" => create_task(true), "b" => create_task(false)}
      @package_compiler.instance_eval do
        @compile_tasks = tasks
        @ready_tasks = [tasks["a"]]
      end

      thread_pool = stub(:ThreadPool)
      thread_pool.should_receive(:wrap).and_yield(thread_pool)
      thread_pool.should_receive(:process).and_yield
      thread_pool.stub(:working?).and_return(true, false)
      BD::ThreadPool.stub(:new).with(:max_threads => 3).and_return(thread_pool)

      @package_compiler.should_receive(:process_task).with(tasks["a"])
      @package_compiler.compile_packages
    end
  end

  describe :process_task do
    it "should compile the package and then enqueue any dependent tasks" do
      @package_compiler.should_receive(:compile_package).with(@task)
      @package_compiler.should_receive(:enqueue_unblocked_tasks).with(@task)
      @package_compiler.process_task(@task)
    end
  end

  describe :reserve_networks
  describe :release_networks

  describe :compile_package do
    it "should compile a package and store the result" do
      agent = stub(:AgentClient)
      dep_spec = {"deps" => "foo"}
      @task.stub(:dependency_key).and_return("dep key")
      @task.stub(:dependency_spec).and_return(dep_spec)

      vm_data = stub(:VmData)
      vm_data.should_receive(:agent).and_return(agent)
      @package_compiler.should_receive(:prepare_vm).with(@stemcell).
          and_yield(vm_data)
      agent.should_receive(:compile_package).
          with("blob-1", "sha-1", "gcc", "1.2.1", dep_spec).
          and_return({"result" => {"sha1" => "sha-2",
                                   "blobstore_id" => "blob-2"}})

      @task.should_receive(:compiled_package=).with do |compiled_package|
        compiled_package.package.should == @package
        compiled_package.stemcell.should == @stemcell
        compiled_package.build.should == 1
        compiled_package.sha1.should == "sha-2"
        compiled_package.blobstore_id.should == "blob-2"
        compiled_package.dependency_key.should == "dep key"
      end

      @package_compiler.compile_package(@task)
    end
  end

  describe :prepare_vm do
    it "should prepare the VM for package compilation" do
      network_reservation = stub(:NetworkReservation)
      @package_compiler.network_reservations = [network_reservation]

      network_settings = {"net" => "ip"}
      @network.stub(:network_settings).with(network_reservation).
          and_return(network_settings)

      vm = BD::Models::Vm.make(:agent_id => "agent-1", :cid => "vm-123")

      vm_creator = stub(:VmCreator)
      vm_creator.should_receive(:create).
          with(@deployment, @stemcell, {"foo" => "bar"},
               {"my-net" => network_settings}, nil, {"env" => "baz"}).
          and_return(vm)
      BD::VmCreator.stub(:new).and_return(vm_creator)

      agent = stub(:AgentClient)
      agent.should_receive(:wait_until_ready)
      BD::AgentClient.stub(:new).with("agent-1").and_return(agent)

      @package_compiler.should_receive(:configure_vm).
          with(vm, agent, {"my-net" => network_settings})
      @cloud.should_receive(:delete_vm).with("vm-123")

      yielded_agent = nil
      @package_compiler.prepare_vm(@stemcell) do |vm_data|
        yielded_agent = vm_data.agent
      end
      yielded_agent.should == agent

      BD::Models::Vm.count.should == 0
    end
  end

  describe :enqueue_unblocked_tasks
  describe :generate_dependency_key
  describe :generate_compile_tasks
  describe :process_package
  describe :process_task_dependencies
  describe :generate_package_index
  describe :bind_dependent_tasks
  describe :generate_reverse_dependencies
  describe :generate_build_number
end
