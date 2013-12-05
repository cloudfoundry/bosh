# Copyright (c) 2009-2013 VMware, Inc.

require "spec_helper"

Bosh::Agent::Infrastructure.new("cloudstack").infrastructure

describe Bosh::Agent::Infrastructure::Cloudstack::Registry do
  before(:each) do
    Bosh::Agent::Infrastructure::Cloudstack::Registry.stub(:meta_data_uri).and_return("http://169.254.169.254/latest")
  end

  let(:user_data) {
    {
      "registry" => {
        "endpoint" => "http://registry_endpoint:25777"
      },
      "server" => {
        "name" => "vm-name"
      },
      "openssh" => {
        "public_key" => "public openssh key"
      }
    }
  }

  describe :get_settings do
    let(:settings_json) {
      {
        "vm" => {
          "name" => "vm-name"
        },
        "agent_id" => "agent-id",
        "networks" => {
          "network_a" => {
            "type" => "manual"
          }
        },
        "disks" => {
          "system" => "/dev/vda",
          "ephemeral" => "/dev/vdb",
          "persistent" => {}
        },
        "env" => {
          "test_env" => "value"
        }
      }
    }
    let(:settings) { Yajl::Encoder.encode({"status" => "ok", "settings" => Yajl::Encoder.encode(settings_json)}) }

    it "should get settings from Bosh registry" do
      Bosh::Agent::Infrastructure::Cloudstack::Registry.stub(:get_registry_endpoint)
          .and_return("http://registry_endpoint")
      Bosh::Agent::Infrastructure::Cloudstack::Registry.should_receive(:get_server_name)
          .and_return("vm-name")
      Bosh::Agent::Infrastructure::Cloudstack::Registry.should_receive(:get_uri)
          .with("http://registry_endpoint/instances/vm-name/settings")
          .and_return(settings)

      settings = Bosh::Agent::Infrastructure::Cloudstack::Registry.get_settings
      settings.should == settings_json
    end

    it "should raise exception when response from Bosh registry is invalid" do
      Bosh::Agent::Infrastructure::Cloudstack::Registry.stub(:get_registry_endpoint)
          .and_return("http://registry_endpoint")
      Bosh::Agent::Infrastructure::Cloudstack::Registry.should_receive(:get_server_name)
          .and_return("vm-name")
      Bosh::Agent::Infrastructure::Cloudstack::Registry.should_receive(:get_uri)
          .and_return("{\"status\":\"error\"}")

      expect {
        Bosh::Agent::Infrastructure::Cloudstack::Registry.get_settings
      }.to raise_error Bosh::Agent::LoadSettingsError, /Invalid response received from Bosh registry/
    end

    it "should raise exception when settings from Bosh registry are invalid" do
      Bosh::Agent::Infrastructure::Cloudstack::Registry.stub(:get_registry_endpoint)
          .and_return("http://registry_endpoint")
      Bosh::Agent::Infrastructure::Cloudstack::Registry.should_receive(:get_server_name)
          .and_return("vm-name")
      Bosh::Agent::Infrastructure::Cloudstack::Registry.should_receive(:get_uri)
          .and_return("{\"status\":\"error\",\"settings\":#{Yajl::Encoder.encode("\"settings\"")}}")

      expect {
        Bosh::Agent::Infrastructure::Cloudstack::Registry.get_settings
      }.to raise_error Bosh::Agent::LoadSettingsError, /Invalid settings received from Bosh registry/
    end

    it "should raise a LoadSettingsError exception when cannot parse settings" do
      Bosh::Agent::Infrastructure::Cloudstack::Registry.stub(:get_registry_endpoint)
          .and_return("http://registry_endpoint")
      Bosh::Agent::Infrastructure::Cloudstack::Registry.should_receive(:get_server_name)
          .and_return("vm-name")
      Bosh::Agent::Infrastructure::Cloudstack::Registry.should_receive(:get_uri)
          .and_return({})

      expect {
        Bosh::Agent::Infrastructure::Cloudstack::Registry.get_settings
      }.to raise_error Bosh::Agent::LoadSettingsError, /Cannot parse settings from Bosh registry/
    end
  end

  describe :get_openssh_key do
    it "should get OpenSSH public key from Cloudstack meta data" do
      Bosh::Agent::Infrastructure::Cloudstack::Registry.should_receive(:get_uri)
          .with("http://169.254.169.254/latest/public-keys")
          .and_return("public openssh key")

      public_key = Bosh::Agent::Infrastructure::Cloudstack::Registry.get_openssh_key
      public_key.should == "public openssh key"
    end

    it "should raise a LoadSettingsError exception when cannot get OpenSSH public key" do
      Bosh::Agent::Infrastructure::Cloudstack::Registry.should_receive(:get_uri)
          .with("http://169.254.169.254/latest/public-keys")
          .and_raise Bosh::Agent::LoadSettingsError
      Bosh::Agent::Infrastructure::Cloudstack::Registry.stub(:get_user_data_from_file)
      Bosh::Agent::Infrastructure::Cloudstack::Registry.should_receive(:parse_user_data)
          .and_return({})

      expect {
        Bosh::Agent::Infrastructure::Cloudstack::Registry.get_openssh_key
      }.to raise_error Bosh::Agent::LoadSettingsError, /Cannot get OpenSSH public key from injected user data file/
    end
  end

  describe :get_server_name do
    it "should get server name" do
      Bosh::Agent::Infrastructure::Cloudstack::Registry.should_receive(:get_user_data)
          .and_return(user_data)

      server_name = Bosh::Agent::Infrastructure::Cloudstack::Registry.get_server_name
      server_name.should == "vm-name"
    end

    it "should raise a LoadSettingsError exception when cannot get server name" do
      Bosh::Agent::Infrastructure::Cloudstack::Registry.should_receive(:get_user_data)
          .and_return({})

      expect {
        Bosh::Agent::Infrastructure::Cloudstack::Registry.get_server_name
      }.to raise_error Bosh::Agent::LoadSettingsError, /Cannot get CloudStack server name from user data/
    end
  end

  describe :get_registry_endpoint do
    it "should get Bosh registry endpoint" do
      Bosh::Agent::Infrastructure::Cloudstack::Registry.should_receive(:get_user_data)
        .and_return(user_data)

      registry_endpoint = Bosh::Agent::Infrastructure::Cloudstack::Registry.get_registry_endpoint
      registry_endpoint.should == "http://registry_endpoint:25777"
    end

    it "should raise a LoadSettingsError exception when cannot get Bosh registry endpoint" do
      Bosh::Agent::Infrastructure::Cloudstack::Registry.should_receive(:get_user_data)
          .and_return({})

      expect {
        Bosh::Agent::Infrastructure::Cloudstack::Registry.get_registry_endpoint
      }.to raise_error Bosh::Agent::LoadSettingsError, /Cannot get Bosh registry endpoint from user data/
    end
  end

  describe :lookup_registry_endpoint do
    context "without dns nameservers" do
      it "should return Bosh registry endpoint" do
        registry_endpoint = Bosh::Agent::Infrastructure::Cloudstack::Registry.lookup_registry_endpoint(user_data)
        registry_endpoint.should == "http://registry_endpoint:25777"
      end
    end

    context "with dns nameservers" do
      let(:user_data_with_dns) {
        user_data_dns = user_data
        user_data_dns["dns"] = { "nameserver" => ["10.11.12.13", "14.15.16.17"] }
        user_data_dns
      }

      it "should return Bosh registry endpoint as an IP address" do
        Bosh::Agent::Infrastructure::Cloudstack::Registry.should_receive(:lookup_registry_ip_address)
            .with("registry_endpoint", ["10.11.12.13", "14.15.16.17"])
            .and_return("4.3.2.1")

        registry_endpoint = Bosh::Agent::Infrastructure::Cloudstack::Registry.lookup_registry_endpoint(user_data_with_dns)
        registry_endpoint.should == "http://4.3.2.1:25777"
      end

      it "should not lookup for an IP address when Bosh registry endpoint is an IP address" do
        user_data_with_ip = user_data_with_dns
        user_data_with_ip["registry"]["endpoint"] = "http://1.2.3.4:25777"
        Bosh::Agent::Infrastructure::Cloudstack::Registry.should_not_receive(:lookup_registry_ip_address)

        registry_endpoint = Bosh::Agent::Infrastructure::Cloudstack::Registry.lookup_registry_endpoint(user_data_with_ip)
        registry_endpoint.should == "http://1.2.3.4:25777"
      end

      it "should raise a LoadSettingsError exception when cannot lookup the hostname" do
        Bosh::Agent::Infrastructure::Cloudstack::Registry.should_receive(:lookup_registry_ip_address)
            .with("registry_endpoint", ["10.11.12.13", "14.15.16.17"])
            .and_raise(Resolv::ResolvError)

        expect {
          Bosh::Agent::Infrastructure::Cloudstack::Registry.lookup_registry_endpoint(user_data_with_dns)
        }.to raise_error Bosh::Agent::LoadSettingsError, /Cannot lookup registry_endpoint using 10.11.12.13, 14.15.16.17/
      end
    end
  end

  describe :get_user_data do
    context "first call" do
      before(:each) do
        Bosh::Agent::Infrastructure::Cloudstack::Registry.user_data = nil
      end

      it "should get user data from Cloudstack user data" do
        Bosh::Agent::Infrastructure::Cloudstack::Registry.should_receive(:get_uri)
            .with("http://169.254.169.254/latest/user-data")
            .and_return(Yajl::Encoder.encode(user_data))

        cloudstack_user_data = Bosh::Agent::Infrastructure::Cloudstack::Registry.get_user_data
        cloudstack_user_data.should == user_data
      end
    end

    context "next calls" do
      before(:each) do
        Bosh::Agent::Infrastructure::Cloudstack::Registry.user_data = user_data
      end

      it "should return previous user data" do
        Bosh::Agent::Infrastructure::Cloudstack::Registry.should_not_receive(:get_uri)
        cloudstack_user_data = Bosh::Agent::Infrastructure::Cloudstack::Registry.get_user_data
        cloudstack_user_data.should == user_data
      end
    end
  end

  describe :parse_user_data do
    it "should parse user data" do
      cloudstack_user_data = Bosh::Agent::Infrastructure::Cloudstack::Registry.parse_user_data(Yajl::Encoder.encode(user_data))
      cloudstack_user_data.should == user_data
    end

    it "should raise a LoadSettingsError exception when cannot parse user data" do
      expect {
        Bosh::Agent::Infrastructure::Cloudstack::Registry.parse_user_data("test")
      }.to raise_error Bosh::Agent::LoadSettingsError, /Cannot parse user data/
    end

    it "should raise a LoadSettingsError exception when user data is not a Hash" do
      expect {
        Bosh::Agent::Infrastructure::Cloudstack::Registry.parse_user_data("")
      }.to raise_error Bosh::Agent::LoadSettingsError, /Invalid user data format, Hash expected/
    end
  end
end
