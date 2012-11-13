require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::WardenCloud::DiskManager do

  Disk = Bosh::WardenCloud::Model::Disk
  DevicePool = Bosh::WardenCloud::DevicePool

  attr_reader :disk_manager

  before(:each) do
    @disk_dir = Dir.mktmpdir
    @disk_manager = Bosh::WardenCloud::DiskManager.new(@disk_dir, DevicePool.new([100,101,102]))
    @disk_manager.stub(:sh).and_return(nil)
  end

  after(:each) do
    FileUtils.rm_r(@disk_dir)
  end

  context "create_disk" do

    it "can create disk" do
      disk = disk_manager.create_disk(20)

      path = disk_path(disk.uuid)
      File.exist?(path).should be_true

      size = File.size(path) / 1024 / 1024
      size.should be_within(1).of(20)
    end

    it "should raise NoDiskSpace exception if system has not enough space" do
      big_size = get_free_space + 10
      expect {
        disk_manager.create_disk(big_size)
      }.to raise_error(Bosh::Clouds::NoDiskSpace)
    end

    it "should raise ArgumentError exception if size is less than 1" do
      expect {
        disk_manager.create_disk(0)
      }.to raise_error(ArgumentError)

      expect {
        disk_manager.create_disk(-10)
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

  def get_free_space
    stat = Sys::Filesystem.stat(@disk_dir)
    stat.block_size * stat.blocks_available / 1024 / 1024
  end

  def disk_path(id)
    File.join(@disk_dir, id)
  end
end
