# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::ProblemHandlers::InactiveDisk do

  def make_handler(disk_id, data = {})
    Bosh::Director::ProblemHandlers::InactiveDisk.new(disk_id, data)
  end

  before(:each) do
    @cloud = instance_double('Bosh::Cloud')
    @agent = double("agent")

    @vm = Bosh::Director::Models::Vm.make(:cid => "vm-cid")

    @instance = Bosh::Director::Models::Instance.
      make(:job => "mysql_node", :index => 3, :vm_id => @vm.id)

    @disk = Bosh::Director::Models::PersistentDisk.
      make(:disk_cid => "disk-cid", :instance_id => @instance.id,
           :size => 300, :active => false)

    @handler = make_handler(@disk.id)
    allow(@handler).to receive(:cloud).and_return(@cloud)
    allow(@handler).to receive(:agent_client).with(@instance.vm).and_return(@agent)
  end

  it "registers under inactive_disk type" do
    handler = Bosh::Director::ProblemHandlers::Base.create_by_type(:inactive_disk, @disk.id, {})
    expect(handler).to be_kind_of(Bosh::Director::ProblemHandlers::InactiveDisk)
  end

  it "has well-formed description" do
    expect(@handler.description).to eq("Disk `disk-cid' (mysql_node/3, 300M) is inactive")
  end

  describe "invalid states" do
    it "is invalid if disk is gone" do
      @disk.destroy
      expect {
        make_handler(@disk.id)
      }.to raise_error("Disk `#{@disk.id}' is no longer in the database")
    end

    it "is invalid if disk is active" do
      @disk.update(:active => true)
      expect {
        make_handler(@disk.id)
      }.to raise_error("Disk `disk-cid' is no longer inactive")
    end
  end

  describe "activate_disk resolution" do
    it "fails if disk is not mounted" do
      expect(@agent).to receive(:list_disk).and_return([])
      expect {
        @handler.apply_resolution(:activate_disk)
      }.to raise_error(Bosh::Director::ProblemHandlerError, "Disk is not mounted")
    end

    it "fails if instance has another persistent disk according to DB" do
      Bosh::Director::Models::PersistentDisk.
        make(:instance_id => @instance.id, :active => true)

      expect(@agent).to receive(:list_disk).and_return(["disk-cid"])

      expect {
        @handler.apply_resolution(:activate_disk)
      }.to raise_error(Bosh::Director::ProblemHandlerError, "Instance already has an active disk")
    end

    it "marks disk as active in DB" do
      expect(@agent).to receive(:list_disk).and_return(["disk-cid"])
      @handler.apply_resolution(:activate_disk)
      @disk.reload

      expect(@disk.active).to be(true)
    end
  end

  describe "delete disk solution" do
    it "fails if disk is mounted" do
      expect(@agent).to receive(:list_disk).and_return(["disk-cid"])
      expect {
        @handler.apply_resolution(:delete_disk)
      }.to raise_error(Bosh::Director::ProblemHandlerError, "Disk is currently in use")
    end

    it "detaches disk from VM and deletes it from DB and cloud (if instance has VM)" do
      expect(@agent).to receive(:list_disk).and_return(["other-disk"])
      expect(@cloud).to receive(:detach_disk).with("vm-cid", "disk-cid")
      expect(@cloud).to receive(:delete_disk).with("disk-cid")
      @handler.apply_resolution(:delete_disk)

      expect {
        @disk.reload
      }.to raise_error(Sequel::Error, "Record not found")
    end

    it "ignores cloud errors and proceeds with deletion from DB" do
      expect(@agent).to receive(:list_disk).and_return(["other-disk"])

      expect(@cloud).to receive(:detach_disk).with("vm-cid", "disk-cid").
        and_raise(RuntimeError.new("Cannot detach disk"))
      expect(@cloud).to receive(:delete_disk).with("disk-cid").
        and_raise(RuntimeError.new("Cannot delete disk"))

      @handler.apply_resolution(:delete_disk)

      expect {
        @disk.reload
      }.to raise_error(Sequel::Error, "Record not found")
    end
  end
end
