require "spec_helper"

describe Bosh::Cli::VersionsIndex do

  def prepare_index(dir, data = nil)
    index_file = File.join(dir, "index.yml")
    return if data.nil?

    File.open(index_file, "w") do |f|
      f.write(YAML.dump(data))
    end
  end

  before :each do
    @dir = Dir.mktmpdir
    prepare_index(@dir)
    @index = Bosh::Cli::VersionsIndex.new(@dir)
  end

  after :each do
    FileUtils.rm_rf(@dir)
  end

  it "can be used to add versioned payloads to index" do
    item1 = { "a" => 1, "b" => 2, "version" => 1 }
    item2 = { "a" => 3, "b" => 4, "version" => 2 }
    @index.add_version("deadbeef", item1, "payload1")
    @index.add_version("deadcafe", item2, "payload2")

    @index.latest_version.should == 2
    @index["deadbeef"].should == item1.merge("sha1" => Digest::SHA1.hexdigest("payload1"))
    @index["deadcafe"].should == item2.merge("sha1" => Digest::SHA1.hexdigest("payload2"))
    @index.version_exists?(1).should be_true
    @index.version_exists?(2).should be_true
    @index.version_exists?(3).should be_false

    @index.filename(1).should == File.join(@dir, "1.tgz")
    @index.filename(2).should == File.join(@dir, "2.tgz")
  end

  it "you shall not pass without version" do
    item_noversion = { "a" => 1, "b" => 2 }
    lambda {
      @index.add_version("deadbeef", item_noversion, "payload1")
    }.should raise_error(Bosh::Cli::InvalidIndex, "Cannot save index entry without knowing its version")
  end

  it "latest version only gets updated if it's greater than current latest" do
    item1 = { "a" => 1, "b" => 2, "version" => 1 }
    item2 = { "a" => 3, "b" => 4, "version" => 2 }
    item3 = { "a" => 3, "b" => 4, "version" => 3 }

    @index.add_version("deadbeef", item1, "payload1")
    @index.add_version("deadcafe", item2, "payload2")
    @index.latest_version.should == 2
    @index.add_version("deadcafe", item1, "payload2")
    @index.latest_version.should == 2
    @index.add_version("deadcafe", item3, "payload3")
    @index.latest_version.should == 3
  end

  it "supports dev versions and proper version comparison when updating latest version" do
    item1 = { "a" => 1, "b" => 2, "version" => "1.9-dev" }
    item2 = { "a" => 3, "b" => 4, "version" => "1.8-dev" }
    item3 = { "a" => 3, "b" => 4, "version" => "1.10-dev" }

    @index.add_version("deadbeef", item1, "payload1")
    @index.add_version("deadcafe", item2, "payload2")
    @index.latest_version.should == "1.9-dev"
    @index.add_version("deadcafe", item1, "payload2")
    @index.latest_version.should == "1.9-dev"
    @index.add_version("deadcafe", item3, "payload3")
    @index.latest_version.should == "1.10-dev"
  end

  it "supports finding entries by checksum" do
    item1 = { "a" => 1, "b" => 2, "version" => 1 }
    item2 = { "a" => 3, "b" => 4, "version" => 2 }

    @index.add_version("deadbeef", item1, "payload1")
    @index.add_version("deadcafe", item2, "payload2")

    checksum1 = Digest::SHA1.hexdigest("payload1")
    checksum2 = Digest::SHA1.hexdigest("payload2")

    @index.find_by_checksum(checksum1).should == item1.merge("sha1" => checksum1)
    @index.find_by_checksum(checksum2).should == item2.merge("sha1" => checksum2)
  end

  it "supports name prefix" do
    item = { "a" => 1, "b" => 2, "version" => 1 }
    @index = Bosh::Cli::VersionsIndex.new(@dir, "foobar")
    @index.add_version("deadbeef", item, "payload1")
    @index.filename(1).should == File.join(@dir, "foobar-1.tgz")
  end

end
