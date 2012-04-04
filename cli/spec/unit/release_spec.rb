# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::Release do

  before :each do
    @release_dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@release_dir, "config"))
  end

  def new_release(dir)
    Bosh::Cli::Release.new(@release_dir)
  end

  it "persists release attributes" do
    r = new_release(@dir)

    r.dev_name.should be_nil
    r.final_name.should be_nil
    r.min_cli_version.should be_nil
    r.latest_release_filename.should be_nil

    r.dev_name = "dev-release"
    r.final_name = "prod-release"
    r.min_cli_version = "0.5.2"
    r.latest_release_filename = "foobar"
    r.save_config

    r2 = new_release(@release_dir)
    r.dev_name.should == "dev-release"
    r.final_name.should == "prod-release"
    r.min_cli_version.should == "0.5.2"
    r.latest_release_filename.should == "foobar"
  end

  it "has attributes persisted in bosh user config" do
    r = new_release(@release_dir)
    r.dev_name = "dev-release"
    r.final_name = "prod-release"
    r.min_cli_version = "0.5.2"
    r.save_config

    FileUtils.rm_rf(File.join(@release_dir, "config", "dev.yml"))

    r = new_release(@release_dir)
    r.dev_name.should be_nil
    r.final_name.should == "prod-release"
    r.min_cli_version.should == "0.5.2"
  end

  it "has attributes persisted in public release config" do
    r = new_release(@release_dir)
    r.dev_name = "dev-release"
    r.final_name = "prod-release"
    r.min_cli_version = "0.5.2"
    r.save_config

    FileUtils.rm_rf(File.join(@release_dir, "config", "final.yml"))

    r = new_release(@release_dir)
    r.dev_name.should == "dev-release"
    r.final_name.should be_nil
    r.min_cli_version.should be_nil
  end

  it "supports private config which gets merged into final config" do
    r = new_release(@release_dir)
    r.dev_name = "dev-release"
    r.final_name = "prod-release"
    r.min_cli_version = "0.5.2"
    r.save_config

    File.open(File.join(@release_dir, "config", "private.yml"), "w") do |f|
      YAML.dump({ "final_name" => "overriden" }, f)
    end

    r = new_release(@release_dir)
    r.final_name.should == "overriden"
    r.min_cli_version.should == "0.5.2"
  end

end
