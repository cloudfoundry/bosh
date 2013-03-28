# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::Jobs::UpdateStemcell do

  before(:each) do
    @cloud = mock("cloud")

    @tmpdir = Dir.mktmpdir("base_dir")

    Bosh::Director::Config.stub!(:cloud).and_return(@cloud)
    Bosh::Director::Config.stub!(:base_dir).and_return(@tmpdir)

    stemcell_contents = create_stemcell("jeos", 5, {"ram" => "2gb"}, "image contents", "shawone")
    @stemcell_file = Tempfile.new("stemcell_contents")
    File.open(@stemcell_file.path, "w") { |f| f.write(stemcell_contents) }
  end

  after(:each) do
    FileUtils.rm_rf(@tmpdir)
    FileUtils.rm_rf(@stemcell_file.path)
  end

  it "should upload the stemcell" do
    @cloud.should_receive(:create_stemcell).with(anything(), {"ram" => "2gb"}).and_return do |image, _|
      contents = File.open(image) { |f| f.read }
      contents.should eql("image contents")
      "stemcell-cid"
    end

    update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path)
    update_stemcell_job.perform

    stemcell = Bosh::Director::Models::Stemcell.find(:name => "jeos", :version => "5")
    stemcell.should_not be_nil
    stemcell.cid.should == "stemcell-cid"
    stemcell.sha1.should == "shawone"
  end

  it "should cleanup the stemcell file" do
    @cloud.should_receive(:create_stemcell).with(anything(), {"ram" => "2gb"}).and_return do |image, _|
      contents = File.open(image) { |f| f.read }
      contents.should eql("image contents")
      "stemcell-cid"
    end

    update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path)
    update_stemcell_job.perform

    File.exist?(@stemcell_file.path).should be_false
  end

  it "should fail if the stemcell exists" do
    Bosh::Director::Models::Stemcell.make(:name => "jeos", :version => "5")

    update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path)

    lambda { update_stemcell_job.perform }.should raise_exception(Bosh::Director::StemcellAlreadyExists)
  end

  it "should fail if cannot extract stemcell" do
    result = Bosh::Exec::Result.new("cmd", "output", 1)
    Bosh::Exec.should_receive(:sh).and_return(result)

    update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path)

    expect {
      update_stemcell_job.perform
    }.to raise_exception(Bosh::Director::StemcellInvalidArchive)
  end
end
