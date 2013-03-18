# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe BD::InstanceDeleter do
  before(:each) do
    @cloud = mock("cloud")
    BD::Config.stub!(:cloud).and_return(@cloud)

    @deployment_plan = mock("deployment_plan")
    @deleter = BD::InstanceDeleter.new(@deployment_plan)
  end

  describe :delete_instances do
    it "should delete the instances with the config max threads option" do
      instances = []
      5.times { instances << mock("instance") }

      BD::Config.stub!(:max_threads).and_return(5)
      pool = mock("pool")
      BD::ThreadPool.stub!(:new).with(:max_threads => 5).and_return(pool)
      pool.stub!(:wrap).and_yield(pool)
      pool.stub!(:process).and_yield

      5.times do |index|
        @deleter.should_receive(:delete_instance).with(instances[index])
      end

      @deleter.delete_instances(instances)
    end

    it "should delete the instances with the respected max threads option" do
      instances = []
      5.times { instances << mock("instance") }

      pool = mock("pool")
      BD::ThreadPool.stub!(:new).with(:max_threads => 2).and_return(pool)
      pool.stub!(:wrap).and_yield(pool)
      pool.stub!(:process).and_yield

      5.times do |index|
        @deleter.should_receive(:delete_instance).with(instances[index])
      end

      @deleter.delete_instances(instances, :max_threads => 2)
    end
  end

  describe :delete_instance do

    it "should delete a single instance" do
      vm = BDM::Vm.make
      instance = BDM::Instance.make(:vm => vm, :job => "test", :index => 5)
      persistent_disks = [BDM::PersistentDisk.make, BDM::PersistentDisk.make]
      persistent_disks.each { |disk| instance.persistent_disks << disk }

      @deleter.should_receive(:drain).with(vm.agent_id)
      @deleter.should_receive(:delete_persistent_disks).with(persistent_disks)
      BD::Config.stub!(:dns_domain_name).and_return("bosh")
      @deleter.should_receive(:delete_dns_records).with("5.test.%.foo.bosh", 0)
      @deployment_plan.should_receive(:canonical_name).and_return("foo")
      domain = stub('domain', :id => 0)
      @deployment_plan.should_receive(:dns_domain).and_return(domain)
      @cloud.should_receive(:delete_vm).with(vm.cid)

      @deleter.delete_instance(instance)

      BDM::Vm[vm.id].should == nil
      BDM::Instance[instance.id].should == nil
    end

  end

  describe :drain do

    it "should drain the VM" do
      agent = mock("agent")
      BD::AgentClient.stub!(:new).with("some_agent_id").and_return(agent)

      agent.should_receive(:drain).with("shutdown").and_return(2)
      agent.should_receive(:stop)
      @deleter.should_receive(:sleep).with(2)

      @deleter.drain("some_agent_id")
    end

    it "should dynamically drain the VM" do
      agent = mock("agent")
      BD::AgentClient.stub!(:new).with("some_agent_id").and_return(agent)
      BD::Config.stub!(:job_cancelled?).and_return(nil)

      agent.should_receive(:drain).with("shutdown").and_return(-2)
      agent.should_receive(:drain).with("status").and_return(1, 0)

      @deleter.should_receive(:sleep).with(2)
      @deleter.should_receive(:sleep).with(1)

      agent.should_receive(:stop)
      @deleter.drain("some_agent_id")
    end

    it "should stop vm-drain if task is cancelled" do
      agent = mock("agent")
      BD::AgentClient.stub!(:new).with("some_agent_id").and_return(agent)
      BD::Config.stub!(:job_cancelled?).and_raise(BD::TaskCancelled.new(1))
      agent.should_receive(:drain).with("shutdown").and_return(-2)
      lambda {@deleter.drain("some_agent_id")}.should raise_error(BD::TaskCancelled)
    end

  end

  describe :delete_persistent_disks do

    it "should delete the persistent disks" do
      persistent_disks = [BDM::PersistentDisk.make(:active => true),
                          BDM::PersistentDisk.make(:active => false)]

      persistent_disks.each do |disk|
        @cloud.should_receive(:delete_disk).with(disk.disk_cid)
      end

      @deleter.delete_persistent_disks(persistent_disks)

      persistent_disks.each do |disk|
        BDM::PersistentDisk[disk.id].should == nil
      end
    end

    it "should ignore errors to inactive persistent disks" do
      disk = BDM::PersistentDisk.make(:active => false)
      @cloud.should_receive(:delete_disk).with(disk.disk_cid).and_raise(Bosh::Clouds::DiskNotFound.new(true))
      @deleter.delete_persistent_disks([disk])
    end

    it "should not ignore errors to active persistent disks" do
      disk = BDM::PersistentDisk.make(:active => true)
      @cloud.should_receive(:delete_disk).with(disk.disk_cid).and_raise(Bosh::Clouds::DiskNotFound.new(true))
      lambda { @deleter.delete_persistent_disks([disk]) }.should raise_error(Bosh::Clouds::DiskNotFound)
    end

  end

  describe :delete_dns do
    it "should generate a correct SQL query string" do
      domain = BDM::Dns::Domain.make
      @deployment_plan.stub!(:canonical_name).and_return("dep")
      @deployment_plan.stub!(:dns_domain).and_return(domain)
      pattern = "0.foo.%.dep.bosh"
      BD::Config.stub!(:dns_domain_name).and_return("bosh")
      @deleter.should_receive(:delete_dns_records).with(pattern, domain.id)
      @deleter.delete_dns("foo", 0)
    end
  end

end
