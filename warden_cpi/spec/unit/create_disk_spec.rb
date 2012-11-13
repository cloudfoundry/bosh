require File.expand_path("../../spec_helper", __FILE__)

describe "create_disk" do

  attr_reader :cloud

  before do
    @cloud = Bosh::WardenCloud::Cloud.new(cloud_options)
  end

  def disk_dir
    cloud_options["disk_dir"]
  end

  def get_free_space
    stat = Sys::Filesystem.stat(disk_dir)
    stat.block_size * stat.blocks_available / 1024 / 1024
  end

  it "should create a disk image" do

    id = cloud.create_disk(20)
    id.should_not be_nil

    File.exist?(File.join(disk_dir, id)).should be_true

    size = File.size(File.join(disk_dir, id)) / 1024 / 1024
    size.should be_within(1).of(20)

    `rm -f "#{File.join(disk_dir, id)}" > /dev/null 2>&1`
    $?.to_i.should == 0
  end

  it "should receive exception if there is not enough free space" do
    big_size = get_free_space + 10
    expect { cloud.create_disk(big_size) }.to raise_error(Bosh::Clouds::NoDiskSpace)
  end

  it "should return nil if size is less than 1" do
    id = cloud.create_disk(0)
    id.should be_nil

    id = cloud.create_disk(-10)
    id.should be_nil
  end

  it "shoud receive exception if the system has internal error" do
    cloud.stub(:exec_sh).and_return(Bosh::Exec::Result.new(nil, nil, 1))
    expect { cloud.create_disk(10) }.to raise_error(Bosh::Clouds::CloudError)
  end
end
