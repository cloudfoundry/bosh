require "spec_helper"

describe Bosh::Cli::Release do
  before do
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
    r.latest_release_filename.should be_nil

    r.dev_name = "dev-release"
    r.final_name = "prod-release"
    r.latest_release_filename = "foobar"
    r.save_config

    r2 = new_release(@release_dir)
    r.dev_name.should == "dev-release"
    r.final_name.should == "prod-release"
    r.latest_release_filename.should == "foobar"
  end

  it "has attributes persisted in bosh user config" do
    r = new_release(@release_dir)
    r.dev_name = "dev-release"
    r.final_name = "prod-release"
    r.save_config

    FileUtils.rm_rf(File.join(@release_dir, "config", "dev.yml"))

    r = new_release(@release_dir)
    r.dev_name.should be_nil
    r.final_name.should == "prod-release"
  end

  it "has attributes persisted in public release config" do
    r = new_release(@release_dir)
    r.dev_name = "dev-release"
    r.final_name = "prod-release"
    r.save_config

    FileUtils.rm_rf(File.join(@release_dir, "config", "final.yml"))

    r = new_release(@release_dir)
    r.dev_name.should == "dev-release"
    r.final_name.should be_nil
  end

  describe "merging final.yml with private.yml" do
    it "should print a warning when it contains blobstore_secret" do
      r = Bosh::Cli::Release.new(spec_asset("config/deprecation"))
      opts = {
        :uid => "bosh",
        :secret => "bar"
      }
      Bosh::Blobstore::Client.should_receive(:safe_create).with("atmos", opts)
      r.should_receive(:say)

      r.blobstore
    end

    it "should detect blobstore secrets for deprecated options" do
      r = Bosh::Cli::Release.new(spec_asset("config/deprecation"))
      r.has_blobstore_secret?.should be(true)
    end

    it "should merge s3 secrets into options" do
      r = Bosh::Cli::Release.new(spec_asset("config/s3"))
      opts = {
        :bucket_name => "test",
        :secret_access_key => "foo",
        :access_key_id => "bar"
      }
      Bosh::Blobstore::Client.should_receive(:safe_create).with("s3", opts)
      r.blobstore
    end

    it "should detect blobstore secrets for s3 options" do
      r = Bosh::Cli::Release.new(spec_asset("config/s3"))
      r.has_blobstore_secret?.should be(true)
    end

    it "should merge atmos secrets into options" do
      r = Bosh::Cli::Release.new(spec_asset("config/atmos"))
      opts = {
        :uid => "bosh",
        :secret => "bar"
      }
      Bosh::Blobstore::Client.should_receive(:safe_create).with("atmos", opts)
      r.blobstore
    end

    it "should detect blobstore secrets for atmos options" do
      r = Bosh::Cli::Release.new(spec_asset("config/atmos"))
      r.has_blobstore_secret?.should be(true)
    end

    it "should merge swift (HP) secrets into options" do
      r = Bosh::Cli::Release.new(spec_asset("config/swift-hp"))
      opts = {
        :container_name => "test",
        :swift_provider => "hp",
        :hp => {
          :hp_access_key => "foo",
          :hp_secret_key => "bar",
          :hp_tenant_id => "foo",
          :hp_avl_zone => "avl"
        }
      }
      Bosh::Blobstore::Client.should_receive(:safe_create).with("swift", opts)
      r.blobstore
    end

    it "should detect blobstore secrets for swift (HP) options" do
      r = Bosh::Cli::Release.new(spec_asset("config/swift-hp"))
      r.has_blobstore_secret?.should be(true)
    end

    it "should merge swift (OpenStack) secrets into options" do
      r = Bosh::Cli::Release.new(spec_asset("config/swift-openstack"))
      opts = {
        :container_name => "test",
        :swift_provider => "openstack",
        :openstack => {
          :openstack_auth_url => "url",
          :openstack_username => "foo",
          :openstack_api_key => "bar",
          :openstack_tenant => "foo",
          :openstack_region => "reg"
        }
      }
      Bosh::Blobstore::Client.should_receive(:safe_create).with("swift", opts)
      r.blobstore
    end

    it "should detect blobstore secrets for swift (OpenStack) options" do
      r = Bosh::Cli::Release.new(spec_asset("config/swift-openstack"))
      r.has_blobstore_secret?.should be(true)
    end

    it "should merge swift (Rackspace) secrets into options" do
      r = Bosh::Cli::Release.new(spec_asset("config/swift-rackspace"))
      opts = {
        :container_name => "test",
        :swift_provider => "rackspace",
        :rackspace => {
          :rackspace_username => "foo",
          :rackspace_api_key => "bar",
          :rackspace_region => "reg"
        }
      }
      Bosh::Blobstore::Client.should_receive(:safe_create).with("swift", opts)
      r.blobstore
    end

    it "should detect blobstore secrets for swift (Rackspace) options" do
      r = Bosh::Cli::Release.new(spec_asset("config/swift-rackspace"))
      r.has_blobstore_secret?.should be(true)
    end

    it "should not throw an error when merging empty secrets into options" do
      r = Bosh::Cli::Release.new(spec_asset("config/local"))
      opts = {
        :blobstore_path => "/tmp/blobstore"
      }
      Bosh::Blobstore::Client.should_receive(:safe_create).with("local", opts)
      r.blobstore
    end

    it "throws an error when blobstore providers does not match" do
      r = Bosh::Cli::Release.new(spec_asset("config/bad-providers"))
      expect {
        r.blobstore
      }.to raise_error(Bosh::Cli::CliError,
        "blobstore private provider does not match final provider")
    end
  end
end
