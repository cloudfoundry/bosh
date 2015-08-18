require "spec_helper"

describe Bosh::Cli::Release do
  before do
    @release_source = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@release_source, "config"))
  end

  def new_release(dir)
    Bosh::Cli::Release.new(@release_source)
  end

  it "persists release attributes" do
    r = new_release(@dir)

    expect(r.dev_name).to be_nil
    expect(r.final_name).to be_nil
    expect(r.latest_release_filename).to be_nil

    r.dev_name = "dev-release"
    r.final_name = "prod-release"
    r.latest_release_filename = "foobar"
    r.save_config

    r2 = new_release(@release_source)
    expect(r2.dev_name).to eq("dev-release")
    expect(r2.final_name).to eq("prod-release")
    expect(r2.latest_release_filename).to eq("foobar")
  end

  it "has attributes persisted in bosh user config" do
    r = new_release(@release_source)
    r.dev_name = "dev-release"
    r.final_name = "prod-release"
    r.save_config

    FileUtils.rm_rf(File.join(@release_source, "config", "dev.yml"))

    r = new_release(@release_source)
    expect(r.dev_name).to be_nil
    expect(r.final_name).to eq("prod-release")
  end

  it "has attributes persisted in public release config" do
    r = new_release(@release_source)
    r.dev_name = "dev-release"
    r.final_name = "prod-release"
    r.save_config

    FileUtils.rm_rf(File.join(@release_source, "config", "final.yml"))

    r = new_release(@release_source)
    expect(r.dev_name).to eq("dev-release")
    expect(r.final_name).to be_nil
  end

  describe "#blobstore" do
    let(:local_release) { Bosh::Cli::Release.new(spec_asset("config/local")) }

    it "returns a blobstore client" do
      opts = {
        :blobstore_path => "/tmp/blobstore"
      }
      expect(Bosh::Blobstore::Client).to receive(:safe_create).with("local", opts).and_call_original
      expect(local_release.blobstore).to be_kind_of(Bosh::Blobstore::BaseClient)
    end

    it "returns the cached blobstore client if previously constructed" do
      expect(Bosh::Blobstore::Client).to receive(:safe_create).and_call_original
      blobstore = local_release.blobstore

      expect(Bosh::Blobstore::Client).to_not receive(:safe_create)
      new_blobstore = local_release.blobstore

      expect(blobstore).to be(new_blobstore)
    end

    it "raises an error when an unknown blobstore provider is configured" do
      r = Bosh::Cli::Release.new(spec_asset("config/unknown-provider"))
      expect {
        r.blobstore
      }.to raise_error(Bosh::Cli::CliError,
        /Cannot initialize blobstore.*Unknown client provider 'unknown-provider-name'/)
    end

    context "when creating a final release" do
      let(:final) { true }
      let(:config_dir) { nil }
      let(:release) { Bosh::Cli::Release.new(config_dir, final) }

      context "when a blobstore is not configured" do
        let(:config_dir) { spec_asset("config/no-blobstore") }

        it "raises an error" do
          release = Bosh::Cli::Release.new(spec_asset("config/no-blobstore"), final)
          expect {
            release.blobstore
          }.to raise_error(Bosh::Cli::CliError,
            "Missing blobstore configuration, please update config/final.yml")
        end
      end

      context "when a blobstore secret is not configured" do
        let(:config_dir) { spec_asset("config/no-blobstore-secret") }

        it "raises an error" do
          expect {
            release.blobstore
          }.to raise_error(Bosh::Cli::CliError,
            "Missing blobstore secret configuration, please update config/private.yml")
        end
      end

      context "when a blobstore is configured" do
        let(:config_dir) { spec_asset("config/local") }

        it "returns the configured blobstore" do
          expect(Bosh::Blobstore::Client).to receive(:safe_create).with("local", {blobstore_path: "/tmp/blobstore"}).and_call_original
          expect(release.blobstore).to be_kind_of(Bosh::Blobstore::BaseClient)
        end
      end
    end

    context "when creating a dev release" do
      let(:final) { false }
      let(:config_dir) { nil }
      let(:release) { Bosh::Cli::Release.new(config_dir, final) }

      context "when a blobstore is not configured" do
        let(:config_dir) { spec_asset("config/no-blobstore") }

        it "prints warning and returns nil" do
          expect(release).to receive(:warning).
            with("Missing blobstore configuration, please update config/final.yml before making a final release")
          expect(Bosh::Blobstore::Client).to_not receive(:safe_create)
          expect(release.blobstore).to be_nil
        end
      end

      context "when a blobstore is configured" do
        let(:config_dir) { spec_asset("config/local") }

        it "returns the configured blobstore" do
          expect(Bosh::Blobstore::Client).to receive(:safe_create).with("local", {blobstore_path: "/tmp/blobstore"}).and_call_original
          expect(release.blobstore).to be_kind_of(Bosh::Blobstore::BaseClient)
        end
      end
    end
  end

  describe "merging final.yml with private.yml" do
    it "should detect blobstore secrets for deprecated options" do
      r = Bosh::Cli::Release.new(spec_asset("config/deprecation"))
      expect(r.has_blobstore_secret?).to eq(true)
    end

    it "should merge s3 secrets into options" do
      r = Bosh::Cli::Release.new(spec_asset("config/s3"))
      opts = {
        :bucket_name => "test",
        :secret_access_key => "foo",
        :access_key_id => "bar"
      }
      expect(Bosh::Blobstore::Client).to receive(:safe_create).with("s3", opts)
      r.blobstore
    end

    it "should detect blobstore secrets for s3 options" do
      r = Bosh::Cli::Release.new(spec_asset("config/s3"))
      expect(r.has_blobstore_secret?).to eq(true)
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
      expect(Bosh::Blobstore::Client).to receive(:safe_create).with("swift", opts)
      r.blobstore
    end

    it "should detect blobstore secrets for swift (HP) options" do
      r = Bosh::Cli::Release.new(spec_asset("config/swift-hp"))
      expect(r.has_blobstore_secret?).to eq(true)
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
      expect(Bosh::Blobstore::Client).to receive(:safe_create).with("swift", opts)
      r.blobstore
    end

    it "should detect blobstore secrets for swift (OpenStack) options" do
      r = Bosh::Cli::Release.new(spec_asset("config/swift-openstack"))
      expect(r.has_blobstore_secret?).to eq(true)
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
      expect(Bosh::Blobstore::Client).to receive(:safe_create).with("swift", opts)
      r.blobstore
    end

    it "should detect blobstore secrets for swift (Rackspace) options" do
      r = Bosh::Cli::Release.new(spec_asset("config/swift-rackspace"))
      expect(r.has_blobstore_secret?).to eq(true)
    end

    it "should merge DAV secrets into options" do
      r = Bosh::Cli::Release.new(spec_asset("config/dav"))
      opts = {
          :endpoint => 'http://bosh-blobstore.some.url.com:8080',
          :user => 'dav-user',
          :password => 'dav-password'
      }
      expect(Bosh::Blobstore::Client).to receive(:safe_create).with("dav", opts)
      r.blobstore
    end

    it "should detect blobstore secrets for DAV options" do
      r = Bosh::Cli::Release.new(spec_asset("config/dav"))
      expect(r.has_blobstore_secret?).to eq(true)
    end


    it 'should not use credentials for a local blobstore' do
      r = Bosh::Cli::Release.new(spec_asset("config/local"))
      expect(r.has_blobstore_secret?).to eq(true)
    end

    it "should not throw an error when merging empty secrets into options" do
      r = Bosh::Cli::Release.new(spec_asset("config/local"))
      opts = {
        :blobstore_path => "/tmp/blobstore"
      }
      expect(Bosh::Blobstore::Client).to receive(:safe_create).with("local", opts)
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
