require 'spec_helper'

describe Bosh::Cli::Release do

  before :each do
    @dir = Dir.mktmpdir
  end

  def new_release(dir, final = false)
    Bosh::Cli::Release.new(dir, final)
  end

  it "has some default config" do
    File.exists?(File.join(@dir, "config", "dev.yml")).should be_false
    r = new_release(@dir)
    r.name.should be_nil
    r.min_cli_version.should == "0.5"
    r.jobs_order.should == []
    r.blobstore_options.should == { }
  end

  it "can be created as dev or final" do
    dr = Bosh::Cli::Release.dev(@dir)
    dr.final?.should be_false

    fr = Bosh::Cli::Release.final(@dir)
    fr.final?.should be_true
  end

  it "supports updating configuration for dev and final separately" do
    r = new_release(@dir)
    r.update_config(:name => "zbcloud")
    r.name.should == "zbcloud"
    r.update_config("name" => "yocloud")
    r.name.should == "yocloud"

    File.exists?(File.join(@dir, "config", "dev.yml")).should be_true
    File.exists?(File.join(@dir, "config", "final.yml")).should be_false

    fr = new_release(@dir, true)
    fr.name.should == nil

    fr.update_config(:name => "blabla")
    fr.name.should == "blabla"

    File.exists?(File.join(@dir, "config", "final.yml")).should be_true
  end

  it "fails if config file is malformed" do
    cnf_file = File.join(@dir, "config", "dev.yml")
    FileUtils.mkdir_p(File.dirname(cnf_file))

    File.open(cnf_file, "w") do |f|
      f.write("garbage")
    end

    lambda { new_release(@dir) }.should raise_error(Bosh::Cli::InvalidRelease)
  end

end
