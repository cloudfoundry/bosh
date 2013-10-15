# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

describe Bosh::Cli::Command::Base do
  before do
    @config = File.join(Dir.mktmpdir, "bosh_config")
    @cache = File.join(Dir.mktmpdir, "bosh_cache")
  end

  describe Bosh::Cli::Command::Micro do
    before do
      @cmd = Bosh::Cli::Command::Micro.new(nil)
      @cmd.add_option(:non_interactive, true)
      @cmd.add_option(:config, @config)
      @cmd.add_option(:cache_dir, @cache)
      @manifest_path = spec_asset("deployment.MF")
      @manifest_yaml = { "name" => "foo", "cloud" => {} }
      @manifest_yaml["resources"] = {
        "persistent_disk" => 16384,
        "cloud_properties" => {}
      }
    end

    it "allows deploying a micro BOSH instance passing stemcell as argument" do
      mock_deployer = double(Bosh::Deployer::InstanceManager)
      mock_deployer.should_receive(:exists?).exactly(2).times
      mock_deployer.should_receive(:renderer=)
      mock_deployer.should_receive(:check_dependencies)
      mock_deployer.should_receive(:create_deployment).with("stemcell.tgz")
      mock_stemcell = double(Bosh::Cli::Stemcell)
      mock_stemcell.should_receive(:validate)
      mock_stemcell.should_receive(:valid?).and_return(true)

      @cmd.stub(:deployment).and_return(@manifest_path)
      @cmd.stub(:load_yaml_file).and_return(@manifest_yaml)
      @cmd.stub(:target_name).and_return("micro-test")
      Bosh::Cli::Stemcell.should_receive(:new).and_return(mock_stemcell)
      @cmd.stub(:deployer).and_return(mock_deployer)
      @cmd.perform("stemcell.tgz")
    end

    it "allows deploying a micro BOSH instance passing stemcell in manifest file" do
      mock_deployer = double(Bosh::Deployer::InstanceManager)
      mock_deployer.should_receive(:exists?).exactly(2).times
      mock_deployer.should_receive(:renderer=)
      mock_deployer.should_receive(:check_dependencies)
      mock_deployer.should_receive(:create_deployment).with("sc-id")

      @cmd.stub(:deployment).and_return(@manifest_path)
      @cmd.stub(:target_name).and_return("micro-test")
      @cmd.stub(:load_yaml_file).and_return(@manifest_yaml)
      @manifest_yaml["resources"]["cloud_properties"]["image_id"] = "sc-id"
      @cmd.stub(:deployer).and_return(mock_deployer)
      @cmd.perform
    end

    it "should not allow deploying a micro BOSH instance if no stemcell is provided" do
      expect {
        @cmd.stub(:deployment).and_return(@manifest_path)
        @manifest_yaml = { "name" => "foo" }
        @cmd.stub(:load_yaml_file).and_return(@manifest_yaml)
        @cmd.perform
      }.to raise_error(Bosh::Cli::CliError, "No stemcell provided")
    end

    it "should require a persistent disk" do
      file = Bosh::Cli::Command::Micro::MICRO_BOSH_YAML
      error_message = "No persistent disk configured in #{file}"
      expect {
        mock_deployer = double(Bosh::Deployer::InstanceManager)
        mock_deployer.should_receive(:check_dependencies)
        mock_deployer.should_receive(:exists?).exactly(1).times

        @cmd.stub(:deployment).and_return(@manifest_path)
        @cmd.stub(:target_name).and_return("micro-test")
        @cmd.stub(:load_yaml_file).and_return(@manifest_yaml)
        @manifest_yaml["resources"]["cloud_properties"]["image_id"] = "sc-id"
        @manifest_yaml["resources"]["persistent_disk"] = nil
        @cmd.stub(:deployer).and_return(mock_deployer)
        @cmd.perform
      }.to raise_error(Bosh::Cli::CliExit, error_message)
    end

    it "should clear cached target values when setting a new deployment" do
      @cmd.stub(:find_deployment).with("foo").and_return(spec_asset("test-bootstrap-config-aws.yml"))
      @cmd.stub_chain(:deployer, :discover_bosh_ip).and_return(nil)

      config = double("config", :target => "target", :resolve_alias => nil, :set_deployment => nil)

      config.should_receive(:target=).with("https://foo:25555")
      config.should_receive(:target_name=).with(nil)
      config.should_receive(:target_version=).with(nil)
      config.should_receive(:target_uuid=).with(nil)
      config.should_receive(:save)

      @cmd.stub(:config).and_return(config)

      @cmd.set_current("foo")
    end

    describe 'agent command' do
      before { @cmd.stub(deployer: deployer) }
      let(:deployer) { double(Bosh::Deployer::InstanceManager, agent: agent) }
      let(:agent)    { double(Bosh::Agent::HTTPClient) }

      it 'sends the command to an agent and shows the returned output' do
        agent.should_receive(:ping).and_return('pong')
        @cmd.should_receive(:say) { |response| expect(response).to include('pong') }
        @cmd.agent('ping')
      end
    end

    describe "deploying/updating with --update-if-exists flag" do
      let(:deployer) { mock(Bosh::Deployer::InstanceManager, :renderer= => nil, :discover_bosh_ip => nil) }

      before do
        deployer.stub(check_dependencies: true)
        @cmd.stub(deployer: deployer)
        @cmd.stub(deployment: @manifest_path)
        @cmd.stub(target_name: "micro-test")
        @cmd.stub(load_yaml_file: @manifest_yaml)
        @cmd.stub(:update_target)
      end

      let(:tarball_path) { "some-stemcell-path" }

      context "when microbosh is not deployed" do
        before { deployer.stub(exists?: false) }

        context "when --update-if-exists flag is given" do
          before { @cmd.add_option(:update_if_exists, true) }

          it "creates microbosh and returns successfully" do
            deployer.should_receive(:create_deployment)
            @cmd.perform(tarball_path)
          end
        end

        context "when --update-if-exists flag is not given" do
          it "creates microbosh and returns successfully" do
            deployer.should_receive(:create_deployment)
            @cmd.perform(tarball_path)
          end
        end
      end

      context "when microbosh is already deployed" do
        before { deployer.stub(exists?: true) }

        context "when --update-if-exists flag is given" do
          before { @cmd.add_option(:update_if_exists, true) }

          it "updates microbosh and returns successfully" do
            deployer.should_receive(:update_deployment)
            @cmd.perform(tarball_path)
          end
        end

        context "when --update-if-exists flag is not given" do
          it "does not update microbosh" do
            deployer.should_not_receive(:update_deployment)
            @cmd.perform(tarball_path) rescue nil
          end

          it "raises an error" do
            expect {
              @cmd.perform(tarball_path)
            }.to raise_error(Bosh::Cli::CliError, /Instance exists/)
          end
        end
      end
    end
  end
end
