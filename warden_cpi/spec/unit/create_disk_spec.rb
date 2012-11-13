require File.expand_path("../../spec_helper", __FILE__)

describe "create_disk" do

  attr_reader :disk_manager

  before do
    @disk_manager = Bosh::WardenCloud::DiskManager.new(disk_options)
  end

  def disk_options
    { "disk_dir" => "/tmp" }
  end

  def disk_dir
    disk_options["disk_dir"]
  end

  def get_free_space
    stat = Sys::Filesystem.stat(disk_dir)
    stat.block_size * stat.blocks_available / 1024 / 1024
  end

  it "should create a disk image" do

    id = disk_manager.create_disk(20)
    id.should_not be_nil

    File.exist?(File.join(disk_dir, id)).should be_true

    size = File.size(File.join(disk_dir, id)) / 1024 / 1024
    size.should be_within(1).of(20)

    FileUtils.rm_f(File.join(disk_dir, id))
  end

  it "should receive exception if there is not enough free space" do
    big_size = get_free_space + 10
    expect { disk_manager.create_disk(big_size) }.to raise_error(Bosh::Clouds::NoDiskSpace)
  end

  it "should return nil if size is less than 1" do
    id = disk_manager.create_disk(0)
    id.should be_nil

    id = disk_manager.create_disk(-10)
    id.should be_nil
  end

  it "shoud receive exception if the system has internal error" do
    disk_manager.stub(:exec_sh).and_return(Bosh::Exec::Result.new(nil, nil, 1))
    expect { disk_manager.create_disk(10) }.to raise_error(Bosh::Clouds::CloudError)
  end
end
