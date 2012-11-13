require File.expand_path("../../spec_helper", __FILE__)

describe "create_disk" do

  attr_reader :disk_manager

  before do
    @disk_dir = Dir.mktmpdir
    @disk_manager = Bosh::WardenCloud::DiskManager.new({ "disk_dir" => @disk_dir })
  end

  after do
    FileUtils.rm_r(@disk_dir)
  end

  def get_free_space
    stat = Sys::Filesystem.stat(@disk_dir)
    stat.block_size * stat.blocks_available / 1024 / 1024
  end

  it "can create a disk image" do

    id = "disk-a"
    disk_manager.create_disk(20, id)

    disk = File.join(@disk_dir, id)
    File.exist?(disk).should be_true

    size = File.size(disk) / 1024 / 1024
    size.should be_within(1).of(20)

    FileUtils.rm_f(disk)
  end

  it "should raise NoDiskSpace exception if system has not enough space" do
    big_size = get_free_space + 10
    expect { disk_manager.create_disk(big_size, "disk-b") }.to raise_error(Bosh::Clouds::NoDiskSpace)
  end

  it "should raise ArgumentError exception if size is less than 1" do
    expect { disk_manager.create_disk(0, "disk-c") }.to raise_error(ArgumentError)
    expect { disk_manager.create_disk(-10, "disk-d") }.to raise_error(ArgumentError)
  end

  it "shoud receive exception if the system has internal error" do
    disk_manager.stub(:exec_sh).and_raise(StandardError)
    expect { disk_manager.create_disk(10, "disk-e") }.to raise_error(StandardError)
  end
end
