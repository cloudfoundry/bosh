# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::VersionsIndex do

  before :each do
    @dir = Dir.mktmpdir
    @index_file = File.join(@dir, "index.yml")
    @index = Bosh::Cli::VersionsIndex.new(@dir)
  end

  after :each do
    FileUtils.rm_rf(@dir)
  end

  it "only creates directory structure on writes to index" do
    File.exists?(@index_file).should be_false
    @index.version_exists?(1).should be_false
    @index["deadbeef"].should be_nil
    @index.latest_version.should be_nil
    File.exists?(@index_file).should be_false

    tmp_file = Tempfile.new("");
    File.open(tmp_file.path, "w") do |f|
      f.write("payload2")
    end
    @index.add_version("deadcafe", { "version" => 2 }, tmp_file.path)
    File.exists?(@index_file).should be_true
  end

  it "chokes on malformed index file" do
    File.open(@index_file, "w") { |f| f.write("deadbeef") }

    lambda {
      @index = Bosh::Cli::VersionsIndex.new(@dir)
    }.should raise_error(Bosh::Cli::InvalidIndex,
                         "Invalid versions index data type, " +
                         "String given, Hash expected")
  end

  it "doesn't choke on empty index file" do
    File.open(@index_file, "w") { |f| f.write("") }
    @index = Bosh::Cli::VersionsIndex.new(@dir)
    @index.latest_version.should be_nil
  end

  it "can be used to add versioned payloads to index" do
    item1 = { "a" => 1, "b" => 2, "version" => 1 }
    item2 = { "a" => 3, "b" => 4, "version" => 2 }
    tmp_file1 = Tempfile.new("");
    File.open(tmp_file1.path, "w") do |f|
      f.write("payload1")
    end
    tmp_file2 = Tempfile.new("");
    File.open(tmp_file2.path, "w") do |f|
      f.write("payload2")
    end
    @index.add_version("deadbeef", item1, tmp_file1.path)
    @index.add_version("deadcafe", item2, tmp_file2.path)

    @index.latest_version.should == 2
    @index["deadbeef"].should ==
        item1.merge("sha1" => Digest::SHA1.hexdigest("payload1"))
    @index["deadcafe"].should ==
        item2.merge("sha1" => Digest::SHA1.hexdigest("payload2"))
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
    }.should raise_error(Bosh::Cli::InvalidIndex,
                         "Cannot save index entry without knowing its version")
  end

  it "latest version only gets updated if it's greater than current latest" do
    item1 = { "a" => 1, "b" => 2, "version" => 1 }
    item2 = { "a" => 3, "b" => 4, "version" => 2 }
    item3 = { "a" => 3, "b" => 4, "version" => 3 }
    tmp_file1 = Tempfile.new("");
    File.open(tmp_file1.path, "w") do |f|
      f.write("payload1")
    end
    tmp_file2 = Tempfile.new("");
    File.open(tmp_file2.path, "w") do |f|
      f.write("payload2")
    end
    tmp_file3 = Tempfile.new("");
    File.open(tmp_file3.path, "w") do |f|
      f.write("payload3")
    end

    @index.add_version("deadbeef", item1, tmp_file1.path)
    @index.add_version("deadcafe", item2, tmp_file2.path)
    @index.latest_version.should == 2
    @index.add_version("addedface", item3, tmp_file2.path)
    @index.latest_version.should == 3
    @index.add_version("facedbeef", item1.merge("version" => "1.5"), tmp_file3.path)
    @index.latest_version.should == 3
  end

  it "supports dev versions and proper version comparison when updating latest version" do
    item1 = { "a" => 1, "b" => 2, "version" => "1.9-dev" }
    item2 = { "a" => 3, "b" => 4, "version" => "1.8-dev" }
    item3 = { "a" => 3, "b" => 4, "version" => "1.10-dev" }
    tmp_file1 = Tempfile.new("");
    File.open(tmp_file1.path, "w") do |f|
      f.write("payload1")
    end
    tmp_file2 = Tempfile.new("");
    File.open(tmp_file2.path, "w") do |f|
      f.write("payload2")
    end
    tmp_file3 = Tempfile.new("");
    File.open(tmp_file3.path, "w") do |f|
      f.write("payload3")
    end

    @index.add_version("deadbeef", item1, tmp_file1.path)
    @index.add_version("deadcafe", item2, tmp_file2.path)
    @index.latest_version.should == "1.9-dev"
    @index.add_version("facedead", item3, tmp_file2.path)
    @index.latest_version.should == "1.10-dev"
    @index.add_version("badbed", item1.merge("version" => "2.15-dev"), tmp_file3.path)
    @index.latest_version.should == "2.15-dev"
  end

  it "doesn't allow duplicate fingerprints or versions" do
    item1 = { "a" => 1, "b" => 2, "version" => "1.9-dev" }
    item2 = { "a" => 3, "b" => 4, "version" => "1.8-dev" }
    tmp_file1 = Tempfile.new("");
    File.open(tmp_file1.path, "w") do |f|
      f.write("payload1")
    end
    tmp_file2 = Tempfile.new("");
    File.open(tmp_file2.path, "w") do |f|
      f.write("payload3")
    end

    @index.add_version("deadbeef", item1, tmp_file1.path)

    lambda {
      @index.add_version("deadcafe", item1, tmp_file2.path)
    }.should raise_error("Trying to add duplicate version `1.9-dev' " +
                         "into index `#{File.join(@dir, "index.yml")}'")
  end

  it "supports finding entries by checksum" do
    item1 = { "a" => 1, "b" => 2, "version" => 1 }
    item2 = { "a" => 3, "b" => 4, "version" => 2 }
    tmp_file1 = Tempfile.new("");
    File.open(tmp_file1.path, "w") do |f|
      f.write("payload1")
    end
    tmp_file2 = Tempfile.new("");
    File.open(tmp_file2.path, "w") do |f|
      f.write("payload2")
    end

    @index.add_version("deadbeef", item1, tmp_file1.path)
    @index.add_version("deadcafe", item2, tmp_file2.path)

    checksum1 = Digest::SHA1.hexdigest("payload1")
    checksum2 = Digest::SHA1.hexdigest("payload2")

    @index.find_by_checksum(checksum1).should == item1.merge("sha1" => checksum1)
    @index.find_by_checksum(checksum2).should == item2.merge("sha1" => checksum2)
  end

  it "supports name prefix" do
    item = { "a" => 1, "b" => 2, "version" => 1 }
    tmp_file1 = Tempfile.new("");
    File.open(tmp_file1.path, "w") do |f|
      f.write("payload1")
    end

    @index = Bosh::Cli::VersionsIndex.new(@dir, "foobar")
    @index.add_version("deadbeef", item, tmp_file1.path)
    @index.filename(1).should == File.join(@dir, "foobar-1.tgz")
  end

end
