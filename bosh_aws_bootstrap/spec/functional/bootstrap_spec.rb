require 'spec_helper'

describe "AWS Bootstrap commands" do
  let(:aws) { Bosh::Cli::Command::AWS.new }
  let(:bosh_config)  { File.expand_path(File.join(File.dirname(__FILE__), "..", "assets", "bosh_config.yml")) }

  before do
    WebMock.disable_net_connect!
    aws.stub(:sleep)
  end

  around do |example|
    @bosh_config = Tempfile.new("bosh_config")
    @bosh_config.puts File.read(bosh_config)
    aws.add_option(:config, @bosh_config.path)
    example.run
    @bosh_config.close
  end

  describe "aws bootstrap micro" do
    around do |example|
      Dir.mktmpdir do |dirname|
        Dir.chdir dirname do
          FileUtils.cp(File.join(File.dirname(__FILE__), "..", "assets", "test-output.yml"), "aws_vpc_receipt.yml")
          FileUtils.cp(File.join(File.dirname(__FILE__), "..", "assets", "test-aws_route53_receipt.yml"), "aws_route53_receipt.yml")
          example.run
        end
      end
    end

    before do
      Bosh::Cli::Command::Micro.any_instance.stub(:micro_deployment)
      Bosh::Cli::Command::Micro.any_instance.stub(:perform)
      Bosh::Cli::Command::User.any_instance.stub(:create)
      Bosh::Cli::Command::Misc.any_instance.stub(:login)
      Bosh::Aws::MicroBoshBootstrap.any_instance.stub(:micro_ami).and_return("ami-123456")
    end

    it "should generate a microbosh.yml in the right location" do
      ::Bosh::Cli::Command::Base.any_instance.stub(:non_interactive?).and_return(true)
      File.exist?("deployments/micro/micro_bosh.yml").should == false
      aws.bootstrap_micro
      File.exist?("deployments/micro/micro_bosh.yml").should == true
    end

    it "should remove any existing deployment artifacts first" do
      ::Bosh::Cli::Command::Base.any_instance.stub(:non_interactive?).and_return(true)
      FileUtils.mkdir_p("deployments/micro")
      File.open("deployments/bosh_registry.log", "w") { |f| f.write("old stuff!") }
      File.open("deployments/micro/leftover.yml", "w") { |f| f.write("old stuff!") }
      File.exist?("deployments/bosh_registry.log").should == true
      File.exist?("deployments/micro/leftover.yml").should == true
      aws.bootstrap_micro
      File.exist?("deployments/bosh_registry.log").should == false
      File.exist?("deployments/micro/leftover.yml").should == false
    end

    it "should deploy a micro bosh" do
      ::Bosh::Cli::Command::Base.any_instance.stub(:non_interactive?).and_return(true)
      Bosh::Cli::Command::Micro.any_instance.should_receive(:micro_deployment).with("micro")
      Bosh::Cli::Command::Micro.any_instance.should_receive(:perform).with("ami-123456")
      aws.bootstrap_micro
    end

    it "should login with admin/admin with non-interactive mode" do
      ::Bosh::Cli::Command::Base.any_instance.stub(:non_interactive?).and_return(true)
      Bosh::Cli::Command::Misc.any_instance.should_receive(:login).with("admin", "admin")
      aws.bootstrap_micro
    end

    it "should login with created user with interactive mode" do
      misc_admin = double('Misc command for admin', :options= => nil)
      misc_foo = double('Misc command for foo', :options= => nil)

      misc_admin.should_receive(:login).with('admin', 'admin')
      misc_foo.should_receive(:login).with('foo', 'foo')

      Bosh::Cli::Command::User.any_instance.should_receive(:create).with("foo", "foo")
      Bosh::Cli::Command::Misc.should_receive(:new).and_return(misc_admin, misc_foo)

      aws.stub(:ask).and_return("foo")
      aws.bootstrap_micro
    end
  end

  describe "aws bootstrap bosh" do
    let(:bosh_repository_path) { File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..")) }
    let(:deployment_name) { 'vpc-bosh-test' }
    let(:stemcell_stub)  { File.expand_path(File.join(File.dirname(__FILE__), "..", "assets", "stemcell_stub.tgz")) }

    let(:deployments) do
      [
          {
              "name" => deployment_name,
              "releases" => [{"name" => "bosh", "version" => "13.1-dev"}],
              "stemcells" => [{"name" => "bosh-stemcell", "version" => "2013-03-21_01-53-17"}]
          }
      ]
    end

    before do
      stub_request(:get, "http://127.0.0.1:25555/info").
          with(:headers => {'Content-Type' => 'application/json'}).
          to_return(:status => 200, :body => '{"uuid": "1234abc"}')

      stub_request(:get, /last_successful_bosh-stemcell_light\.tgz$/).
          to_return(:status => 200, :body => File.read(stemcell_stub))
    end

    around do |example|
      Dir.mktmpdir do |dirname|
        Dir.chdir dirname do
          FileUtils.cp(File.join(File.dirname(__FILE__), "..", "assets", "test-output.yml"), "aws_vpc_receipt.yml")
          FileUtils.cp(File.join(File.dirname(__FILE__), "..", "assets", "test-aws_route53_receipt.yml"), "aws_route53_receipt.yml")
          example.run

        end
      end
    end

    before do
      Bosh::Cli::Config.output = $stdout
      Bosh::Cli::Config.cache = Bosh::Cli::Cache.new(Dir.mktmpdir)
    end

    context "when the target is not set" do
      before do
        aws.options[:target] = nil
        aws.config.target = nil
      end

      it "raises an error" do
        expect { aws.bootstrap_bosh(bosh_repository_path) }.to raise_error(/Please choose target first/)
      end
    end

    context "when the target has a release" do
      before do
        aws.config.target = aws.options[:target] = 'http://localhost:25555'

        releases = [
            {
                "name" => "bosh",
                "release_versions" => [
                    {
                        "version" => "13.1-dev",
                        "commit_hash" => "5c9d7254",
                        "uncommitted_changes" => false,
                        "currently_deployed" => true
                    }
                ]
            }
        ]

        stub_request(:get, "http://127.0.0.1:25555/releases").
            with(:headers => {'Content-Type' => 'application/json'}).
            to_return(:status => 200, :body => releases.to_json)
      end

      it "raises an error" do
        expect do
          aws.bootstrap_bosh(bosh_repository_path)
        end.to raise_error(/This target already has a release./)
      end
    end

    context "when bosh_repository is not specified" do
      before do
        aws.options[:target] = 'http://localhost:25555'
      end

      it "complains about its presence" do
        expect { aws.bootstrap_bosh }.to raise_error(/A path to a BOSH source repository must be given as an argument or set in the `BOSH_REPOSITORY' environment variable/)
      end
    end

    context "when bosh_repository is specified via an env variable" do
      before do
        aws.options[:target] = 'http://localhost:25555'
      end

      after do
        ENV.delete('BOSH_REPOSITORY')
      end

      it "does not fail on bosh repo path" do
        ENV['BOSH_REPOSITORY'] = "/"

        expect { aws.bootstrap_bosh }.to_not raise_error(/A path to a BOSH source repository must be given as an argument or set in the `BOSH_REPOSITORY' environment variable/)
      end
    end

    context "when the release path is not an actual release" do
      let(:tmpdir) { Dir.mktmpdir }

      before do
        aws.options[:target] = 'http://localhost:25555'
        Dir.chdir(tmpdir) do
          Dir.mkdir("release")
        end
      end

      it "complains about its presence" do
        expect { aws.bootstrap_bosh(tmpdir.to_s) }.to raise_error(/Please point to a valid release folder/)
      end
    end

    context "when the target already have a deployment" do
      # This deployment name comes from test-output.yml asset file.
      let(:deployment_name) { "vpc-bosh-dev102" }

      before do
        aws.options[:target] = 'http://localhost:25555'

        stub_request(:get, "http://127.0.0.1:25555/releases").
            with(:headers => {'Content-Type' => 'application/json'}).
            to_return(:status => 200, :body => "[]")

        stub_request(:get, "http://127.0.0.1:25555/deployments").
            with(:headers => {'Content-Type' => 'application/json'}).
            to_return(:status => 200, :body => deployments.to_json)
      end

      it "bails telling the user this command is only useful for the initial deployment" do
        expect { aws.bootstrap_bosh(bosh_repository_path) }.to raise_error(/Deployment `#{deployment_name}' already exists\./)
      end
    end

    context "when the prerequisites are all met" do
      let(:username) { "bosh_username" }
      let(:password) { "bosh_password" }

      before do
        Bosh::Cli::PackageBuilder.any_instance.stub(:resolve_globs).and_return([])
        Bosh::Exec.should_receive(:sh).with("bundle exec rake release:create_dev_release")

        aws.config.target = aws.options[:target] = 'http://127.0.0.1:25555'
        aws.config.set_alias('target', '1234', 'http://127.0.0.1:25555')
        aws.config.save


        # FIXME This should be read from the bosh_config.yml file
        # but for some reason, auth is not being read properly
        aws.options[:username] = "admin"
        aws.options[:password] = "admin"

        # Verify deployment's existence
        stub_request(:get, "http://127.0.0.1:25555/deployments").
            with(:headers => {'Content-Type' => 'application/json'}).
            to_return(:status => 200, :body => deployments.to_json)

        stub_request(:get, "http://127.0.0.1:25555/releases").
            with(:headers => {'Content-Type' => 'application/json'}).
            to_return(:status => 200, :body => "[]")

        stub_request(:get, %r{http://blob.cfblob.com/rest/objects}).
            to_return(:status => 200)

        stub_request(:post, %r{packages/matches}).
            to_return(:status => 200, :body => "[]")

        @upload_request = stub_request(:post, "http://127.0.0.1:25555/releases").
            to_return(:status => 200, :body => "")

        stub_request(:get, "http://127.0.0.1:25555/stemcells").
            to_return(:status => 200, :body => "[]").then.
            to_return(:status => 200, :body => '[{"name":"bosh-stemcell","version":"2013-03-21_01-53-17","cid":"ami-1c990175"}]')

        @stemcell_upload_request = stub_request(:post, "http://127.0.0.1:25555/stemcells").
            to_return(:status => 200, :body => "")

        # Checking for previous deployments properties from the receipt file.
        stub_request(:get, "http://127.0.0.1:25555/deployments/vpc-bosh-dev102/properties").
            to_return(:status => 200, :body => "[]")

        @deployment_request = stub_request(:post, "http://127.0.0.1:25555/deployments").
            to_return(:status => 200, :body => "")

        new_target_info = {
            "uuid" => "defg9876",
            "name" =>  deployment_name,
            "version" => "1234"
        }

        stub_request(:get, "http://50.200.100.3:25555/info").
            with(:headers => {'Content-Type' => 'application/json'}).
            to_return(:status => 200, :body => new_target_info.to_json).
            to_return(:status => 200, :body => {"user" => "admin"}.to_json).
            to_return(:status => 200, :body => {"user" => username}.to_json)

        aws.should_receive(:ask).with("Enter username: ").and_return(username)
        aws.should_receive(:ask).with("Enter password: ").and_return(password)

        @create_user_request = stub_request(:post, "http://50.200.100.3:25555/users").
            with(:body => {username: username, password: password}.to_json).
            to_return(:status => 204, :body => new_target_info.to_json)
      end

      it "generates an updated manifest for bosh" do
        File.exist?("deployments/bosh/bosh.yml").should be_false
        aws.bootstrap_bosh(bosh_repository_path)
        File.exist?("deployments/bosh/bosh.yml").should be_true
      end

      it "creates a new release" do
        aws.bootstrap_bosh(bosh_repository_path)

        releases = Dir["#{bosh_repository_path}/release/dev_releases/*"]

        releases.select do |release_file|
          release_file.include?("index.yml") &&
              release_file.include?(".1-dev.yml")
        end

        releases.size.should >= 2
      end

      it "uploads the newly created release" do
        aws.bootstrap_bosh(bosh_repository_path)

        @upload_request.should have_been_made
      end

      it "runs deployment diff" do
        aws.bootstrap_bosh(bosh_repository_path)

        generated_manifest = File.read("deployments/bosh/bosh.yml")
        generated_manifest.should include("# Fake network properties to satisfy bosh diff")
      end

      it "uploads the latest stemcell" do
        aws.bootstrap_bosh(bosh_repository_path)

        @stemcell_upload_request.should have_been_made
      end

      it "deploys bosh" do
        aws.bootstrap_bosh(bosh_repository_path)

        @deployment_request.should have_been_made
      end

      it "sets the target to the new bosh" do
        aws.bootstrap_bosh(bosh_repository_path)

        config_file = File.read(@bosh_config.path)
        config = YAML.load(config_file)
        config["target"].should == "http://50.200.100.3:25555"
      end

      it "creates a new user in new bosh" do
        aws.bootstrap_bosh(bosh_repository_path)

        encoded_credentials = Base64.encode64("admin:admin").strip
        a_request(:get, "50.200.100.3:25555/info").with(
            :headers => {
                'Authorization' => "Basic #{encoded_credentials}",
                'Content-Type'=>'application/json'
            }).should have_been_made.once

        @create_user_request.should have_been_made

        encoded_credentials = Base64.encode64("#{username}:#{password}").strip
        a_request(:get, "50.200.100.3:25555/info").with(
            :headers => {
                'Authorization' => "Basic #{encoded_credentials}",
                'Content-Type'=>'application/json'
            }).should have_been_made.once
      end
    end
  end
end