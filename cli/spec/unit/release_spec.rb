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

  describe "merging final.yml with private.yml" do
    it "should print a warning when it contains blobstore_secret" do
      r = Bosh::Cli::Release.new(spec_asset("config/deprecation"))
      opts = {
          :uid => "bosh",
          :secret => "bar"
      }
      Bosh::Blobstore::Client.should_receive(:create).with("atmos", opts)
      r.should_receive(:say)

      r.blobstore
    end

    it "should detect blobstore secrets for deprecated options" do
      r = Bosh::Cli::Release.new(spec_asset("config/deprecation"))
      r.has_blobstore_secret?.should be_true
    end

    it "should merge s3 secrets into options" do
      r = Bosh::Cli::Release.new(spec_asset("config/s3"))
      opts = {
          :bucket_name => "test",
          :secret_access_key => "foo",
          :access_key_id => "bar"
      }
      Bosh::Blobstore::Client.should_receive(:create).with("s3", opts)
      r.blobstore
    end

    it "should detect blobstore secrets for s3 options" do
      r = Bosh::Cli::Release.new(spec_asset("config/s3"))
      r.has_blobstore_secret?.should be_true
    end

    it "should merge atmos secrets into options" do
      r = Bosh::Cli::Release.new(spec_asset("config/atmos"))
      opts = {
          :uid => "bosh",
          :secret => "bar"
      }
      Bosh::Blobstore::Client.should_receive(:create).with("atmos", opts)
      r.blobstore
    end

    it "should detect blobstore secrets for atmos options" do
      r = Bosh::Cli::Release.new(spec_asset("config/atmos"))
      r.has_blobstore_secret?.should be_true
    end

    it "should merge swift (HP) secrets into options" do
      r = Bosh::Cli::Release.new(spec_asset("config/swift-hp"))
      opts = {
          :container_name => "test",
          :swift_provider => "hp",
          :hp => {
            :hp_account_id => "foo",
            :hp_secret_key => "bar",
            :hp_tenant_id => "foo"
          }
      }
      Bosh::Blobstore::Client.should_receive(:create).with("swift", opts)
      r.blobstore
    end

    it "should detect blobstore secrets for swift (HP) options" do
      r = Bosh::Cli::Release.new(spec_asset("config/swift-hp"))
      r.has_blobstore_secret?.should be_true
    end

    it "should merge swift (Rackspace) secrets into options" do
      r = Bosh::Cli::Release.new(spec_asset("config/swift-rackspace"))
      opts = {
          :container_name => "test",
          :swift_provider => "rackspace",
          :rackspace => {
            :rackspace_username => "foo",
            :rackspace_api_key => "bar"
          }
      }
      Bosh::Blobstore::Client.should_receive(:create).with("swift", opts)
      r.blobstore
    end

    it "should detect blobstore secrets for swift (Rackspace) options" do
      r = Bosh::Cli::Release.new(spec_asset("config/swift-rackspace"))
      r.has_blobstore_secret?.should be_true
    end

    it "should not throw an error when merging empty secrets into options" do
      r = Bosh::Cli::Release.new(spec_asset("config/local"))
      opts = {
          :blobstore_path => "/tmp/blobstore"
      }
      Bosh::Blobstore::Client.should_receive(:create).with("local", opts)
      r.blobstore
    end

    it "throws an error when blobstore providers does not match" do
      r = Bosh::Cli::Release.new(spec_asset("config/bad-providers"))
      expect {
        r.blobstore
      }.to raise_error(Bosh::Cli::CliError, "blobstore private provider " +
          "does not match final provider")

    end
  end

  describe "merging private and final config for a composite blobstore" do
    it "should properly merge the options for each inner blobstore" do
      r = Bosh::Cli::Release.new(spec_asset("config/composite/good"))
      opts = {
          :blobstores => [
              {
                  'name' => 'b1',
                  'options' => {
                      'final_b1a' => 'final_b1a_val',
                      'both_b1b' => 'private_b1b_val',
                      'private_b1c' => 'private_b1c_val'
                  }
              },
              {
                  'name' => 'b2',
                  'options' => {
                      'private_b2' => 'private_b2_val'
                  }
              },
              {
                  'name' => 'b3',
                  'options' => {
                      'final_b3' => 'final_b3_val'
                  }
              }
          ]
      }
      Bosh::Blobstore::Client.should_receive(:create).with("composite", opts)
      r.blobstore
    end

    it "raises an error when inner blobstores' names do not match for a given index" do
      r = Bosh::Cli::Release.new(spec_asset("config/composite/mismatched_names"))
      expect {
        r.blobstore
      }.to raise_error(Bosh::Cli::CliError, /Inner blobstore with name 'wrong_name' .+ does not match the name of the corresponding blobstore/)
    end

    it "raises an error if an inner blobstore in final.yml does not have a name" do
      r = Bosh::Cli::Release.new(spec_asset("config/composite/no_name_in_final"))
      expect {
        r.blobstore
      }.to raise_error(Bosh::Cli::CliError, /Component blobstore at index 1 .+final.yml does not have a 'name'/)
    end

    it "raises an error if an inner blobstore in private.yml does not have a name" do
      r = Bosh::Cli::Release.new(spec_asset("config/composite/no_name_in_private"))
      expect {
        r.blobstore
      }.to raise_error(Bosh::Cli::CliError, /Component blobstore at index 1 .+private.yml does not have a 'name'/)
    end

    it "raises an error if an inner blobstore in final config is not found in private config" do
      r = Bosh::Cli::Release.new(spec_asset("config/composite/blobstore_missing_from_private"))
      expect {
        r.blobstore
      }.to raise_error(Bosh::Cli::CliError, /Each of a composite blobstore's inner blobstores .+ must also be in .*private.yml/)
    end

  end
end
