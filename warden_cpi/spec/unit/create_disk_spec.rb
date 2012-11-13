require File.expand_path("../../spec_helper", __FILE__)

describe "create_disk" do

  attr_reader :cloud

  before do
    options = { :disk_dir => "/tmp" }
    @cloud = Bosh::WardenCloud::Cloud.new(options)
  end

  def get_free_space
    stat = Sys::Filesystem.stat("/tmp")
    stat.block_size * stat.blocks_available / 1024 / 1024
  end

  it "should create a disk image" do

    id = cloud.create_disk(20)
    id.should_not be_nil

    File.exist?("/tmp/#{id}").should be_true

    size = File.size("/tmp/#{id}") / 1024 / 1024
    size.should be_within(1).of(20)

    `rm -f "/tmp/#{id}" > /dev/null 2>&1`
    $?.to_i.should == 0
  end

  it "should get exception if there is not enough free space" do
    big_size = get_free_space + 10
    expect { cloud.create_disk(big_size) }.to raise_error(Bosh::Clouds::NoDiskSpace)
  end

  it "should return nil if size is less than 1" do
    id = cloud.create_disk(0)
    id.should be_nil
  end
end
