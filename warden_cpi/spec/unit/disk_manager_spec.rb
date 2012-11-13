require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::WardenCloud::DiskManager do

  Disk = Bosh::WardenCloud::Model::Disk

  attr_reader :disk_manager

  before(:each) do
    @disk_dir = Dir.mktmpdir
    @disk_manager = Bosh::WardenCloud::DiskManager.new({ "disk_dir" => @disk_dir })
    @disk_manager.stub(:sh).and_return(nil)
  end

  after(:each) do
    FileUtils.rm_r(@disk_dir)
  end

  def get_free_space
    stat = Sys::Filesystem.stat(@disk_dir)
    stat.block_size * stat.blocks_available / 1024 / 1024
  end

  def disk_path(id)
    File.join(@disk_dir, id)
  end

  context "disk_exist?" do

    it "should be true if disk exists" do
      FileUtils.touch(disk_path("test"))
      disk = Disk.new("test", 1)
      disk_manager.disk_exist?(disk).should be_true
    end

    it "should be false if disk not exists" do
      disk = Disk.new("test", 1)
      disk_manager.disk_exist?(disk).should_not be_true
    end
  end

  context "create_disk" do

    it "can create disk" do
      disk = Disk.new("test", 1)
      disk_manager.create_disk(disk, 20)

      path = disk_path("test")
      File.exist?(path).should be_true

      size = File.size(path) / 1024 / 1024
      size.should be_within(1).of(20)
    end

    it "should raise NoDiskSpace exception if system has not enough space" do
      big_size = get_free_space + 10
      disk = Disk.new("test", 1)
      expect {
        disk_manager.create_disk(disk, big_size)
      }.to raise_error(Bosh::Clouds::NoDiskSpace)
    end

    it "should raise ArgumentError exception if size is less than 1" do
      disk = Disk.new("test", 1)

      expect {
        disk_manager.create_disk(disk, 0)
      }.to raise_error(ArgumentError)

      expect {
        disk_manager.create_disk(disk, -10)
      }.to raise_error(ArgumentError)
    end
  end

  context "delete_disk" do

    it "can delete a disk" do
      FileUtils.touch(disk_path("test"))
      disk = Disk.new("test", 1000)
      disk_manager.delete_disk(disk)
      File.exist?(disk_path("test")).should_not be_true
    end
  end
end
