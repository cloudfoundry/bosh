require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::InstanceDeleter do
  include Bosh::Director

  before(:each) do
    @cloud = mock("cloud")
    Config.stub!(:cloud).and_return(@cloud)

    @deployment_plan = mock("deployment_plan")
    @deleter = InstanceDeleter.new(@deployment_plan)
  end

  describe :delete_instances do
    it "should delete the instances with the respected max threads option" do
      instances = []
      5.times { instances << mock("instance") }

      pool = mock("pool")
      ThreadPool.stub!(:new).with(:max_threads => 2).and_return(pool)
      pool.stub!(:wrap).and_yield(pool)
      pool.stub!(:process).and_return { |*args| args.first.call }

      5.times do |index|
        @deleter.should_receive(:delete_instance).with(instances[index])
      end

      @deleter.delete_instances(instances, :max_threads => 2)
    end
  end

  describe :delete_instance do

    it "should delete a single instance" do
      vm = Models::Vm.make
      instance = Models::Instance.make(:vm => vm, :job => "test", :index => 5)
      persistent_disks = [Models::PersistentDisk.make, Models::PersistentDisk.make]
      persistent_disks.each { |disk| instance.persistent_disks << disk }

      @deleter.should_receive(:drain).with(vm.agent_id)
      @deleter.should_receive(:delete_persistent_disks).with(persistent_disks)
      @deleter.should_receive(:delete_dns_records).with("test", 5)
      @cloud.should_receive(:delete_vm).with(vm.cid)

      @deleter.delete_instance(instance)

      Models::Vm[vm.id].should == nil
      Models::Instance[instance.id].should == nil
    end

  end

  describe :drain do

    it "should drain the VM" do
      agent = mock("agent")
      AgentClient.stub!(:new).with("some_agent_id").and_return(agent)

      agent.should_receive(:drain).with("shutdown").and_return(2)
      agent.should_receive(:stop)
      @deleter.should_receive(:sleep).with(2)

      @deleter.drain("some_agent_id")
    end

    it "should dynamically drain the VM" do
      agent = mock("agent")
      AgentClient.stub!(:new).with("some_agent_id").and_return(agent)
      Bosh::Director::Config.stub!(:job_cancelled?).and_return(nil)

      agent.should_receive(:drain).with("shutdown").and_return(-2)
      agent.should_receive(:drain).with("status").and_return(1, 0)

      @deleter.should_receive(:sleep).with(2)
      @deleter.should_receive(:sleep).with(1)

      agent.should_receive(:stop)
      @deleter.drain("some_agent_id")
    end

    it "should stop vm-drain if task is cancelled" do
      agent = mock("agent")
      AgentClient.stub!(:new).with("some_agent_id").and_return(agent)
      Bosh::Director::Config.stub!(:job_cancelled?).and_raise(Bosh::Director::TaskCancelled.new(1))
      agent.should_receive(:drain).with("shutdown").and_return(-2)
      lambda {@deleter.drain("some_agent_id")}.should raise_error(Bosh::Director::TaskCancelled)
    end

  end

  describe :delete_persistent_disks do

    it "should delete the persistent disks" do
      persistent_disks = [Models::PersistentDisk.make(:active => true),
                          Models::PersistentDisk.make(:active => false)]

      persistent_disks.each do |disk|
        @cloud.should_receive(:delete_disk).with(disk.disk_cid)
      end

      @deleter.delete_persistent_disks(persistent_disks)

      persistent_disks.each do |disk|
        Models::PersistentDisk[disk.id].should == nil
      end
    end

    it "should ignore errors to inactive persistent disks" do
      disk = Models::PersistentDisk.make(:active => false)
      @cloud.should_receive(:delete_disk).with(disk.disk_cid).and_raise(DiskNotFound.new(true))
      @deleter.delete_persistent_disks([disk])
    end

    it "should not ignore errors to active persistent disks" do
      disk = Models::PersistentDisk.make(:active => true)
      @cloud.should_receive(:delete_disk).with(disk.disk_cid).and_raise(DiskNotFound.new(true))
      lambda { @deleter.delete_persistent_disks([disk]) }.should raise_error(DiskNotFound)
    end

  end

  describe :delete_dns_records do

    it "should only delete records that match the deployment, job, and index" do
      domain = Models::Dns::Domain.make
      @deployment_plan.stub!(:canonical_name).and_return("dep")
      @deployment_plan.stub!(:dns_domain).and_return(domain)

      Models::Dns::Record.make(:domain => domain, :name => "0.job-a.network-a.dep.bosh")
      Models::Dns::Record.make(:domain => domain, :name => "1.job-a.network-a.dep.bosh")
      Models::Dns::Record.make(:domain => domain, :name => "0.job-b.network-b.dep.bosh")
      Models::Dns::Record.make(:domain => domain, :name => "0.job-a.network-a.dep-b.bosh")

      @deleter.delete_dns_records("job-a", 0)

      remaining_names = Set.new
      Models::Dns::Record.each { |record| remaining_names << record.name }
      remaining_names.should == Set.new(["1.job-a.network-a.dep.bosh",
                                         "0.job-b.network-b.dep.bosh",
                                         "0.job-a.network-a.dep-b.bosh"])
    end

    it "should delete records that match the canonical names" do
      domain = Models::Dns::Domain.make
      @deployment_plan.stub!(:canonical_name).and_return("dep_a")
      @deployment_plan.stub!(:dns_domain).and_return(domain)

      Models::Dns::Record.make(:domain => domain, :name => "0.job-a.network-a.dep-a.bosh")
      Models::Dns::Record.make(:domain => domain, :name => "1.job-a.network-a.dep-a.bosh")
      Models::Dns::Record.make(:domain => domain, :name => "0.job-b.network-b.dep-a.bosh")
      Models::Dns::Record.make(:domain => domain, :name => "0.job-a.network-a.dep-b.bosh")

      @deleter.delete_dns_records("job_a", 0)

      remaining_names = Set.new
      Models::Dns::Record.each { |record| remaining_names << record.name }
      remaining_names.should == Set.new(["1.job-a.network-a.dep-a.bosh",
                                         "0.job-b.network-b.dep-a.bosh",
                                         "0.job-a.network-a.dep-b.bosh"])
    end

  end

end
