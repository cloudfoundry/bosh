require "spec_helper"

describe Bosh::AwsCliPlugin::MicroBoshBootstrap do
  let(:hm_director_account_options) { {hm_director_user: 'hm', hm_director_password: 'hmpasswd'} }
  let(:bootstrap) { described_class.new(nil, hm_director_account_options) }

  describe "micro_ami" do
    context "when the environment provides an override AMI" do
      before(:all) do
        ENV["BOSH_OVERRIDE_MICRO_STEMCELL_AMI"] = 'ami-tgupta'
      end

      after(:all) do
        ENV.delete "BOSH_OVERRIDE_MICRO_STEMCELL_AMI"
      end

      it "uses the given AMI" do
        expect(bootstrap.micro_ami).to eq('ami-tgupta')
      end
    end

    context "when the environment does not provide an override AMI" do
      before do
        expect(Net::HTTP).to receive(:get).with("bosh-jenkins-artifacts.s3.amazonaws.com", "/last_successful-bosh-stemcell-aws_ami_us-east-1").and_return("ami-david")
      end

      it "returns the content from S3" do
        expect(bootstrap.micro_ami).to eq("ami-david")
      end
    end
  end

  describe "deploying microbosh" do
    let(:microbosh_bootstrap) { described_class.new(nil, hm_director_account_options.merge(non_interactive: true)) }

    before do
      allow_any_instance_of(Bosh::Cli::Command::Micro).to receive(:micro_deployment)
      allow_any_instance_of(Bosh::Cli::Command::Micro).to receive(:perform)
      allow_any_instance_of(Bosh::Cli::Command::User).to receive(:create)
      allow_any_instance_of(Bosh::Cli::Command::Login).to receive(:login)
      allow_any_instance_of(Bosh::AwsCliPlugin::MicroBoshBootstrap).to receive(:micro_ami).and_return("ami-123456")
    end

    around do |example|
      Dir.mktmpdir do |dirname|
        Dir.chdir dirname do
          FileUtils.cp(asset("test-output.yml"), "aws_vpc_receipt.yml")
          FileUtils.cp(asset("test-aws_route53_receipt.yml"), "aws_route53_receipt.yml")
          example.run
        end
      end
    end

    it "should generate a microbosh.yml in the right location" do
      allow_any_instance_of(::Bosh::Cli::Command::Base).to receive(:non_interactive?).and_return(true)
      expect(File.exist?("deployments/micro/micro_bosh.yml")).to eq(false)
      microbosh_bootstrap.start
      expect(File.exist?("deployments/micro/micro_bosh.yml")).to eq(true)
    end

    it "should remove any existing deployment artifacts first" do
      allow_any_instance_of(::Bosh::Cli::Command::Base).to receive(:non_interactive?).and_return(true)
      FileUtils.mkdir_p("deployments/micro")
      File.open("deployments/bosh-registry.log", "w") { |f| f.write("old stuff!") }
      File.open("deployments/micro/leftover.yml", "w") { |f| f.write("old stuff!") }
      expect(File.exist?("deployments/bosh-registry.log")).to eq(true)
      expect(File.exist?("deployments/micro/leftover.yml")).to eq(true)
      microbosh_bootstrap.start
      expect(File.exist?("deployments/bosh-registry.log")).to eq(false)
      expect(File.exist?("deployments/micro/leftover.yml")).to eq(false)
    end

    it "should deploy a micro bosh" do
      allow_any_instance_of(::Bosh::Cli::Command::Base).to receive(:non_interactive?).and_return(true)
      expect_any_instance_of(Bosh::Cli::Command::Micro).to receive(:micro_deployment).with("micro")
      expect_any_instance_of(Bosh::Cli::Command::Micro).to receive(:perform).with("ami-123456")
      microbosh_bootstrap.start
    end

    it "should login with admin/admin with non-interactive mode" do
      allow_any_instance_of(::Bosh::Cli::Command::Base).to receive(:non_interactive?).and_return(true)
      expect_any_instance_of(Bosh::Cli::Command::Login).to receive(:login).with("admin", "admin")
      microbosh_bootstrap.start
    end

    it "should login with created user with interactive mode" do
      login_admin = double('Misc command for admin', :options= => nil)
      login_foo = double('Misc command for foo', :options= => nil)

      expect(login_admin).to receive(:login).with('admin', 'admin')
      expect(login_foo).to receive(:login).with('foo', 'foo')

      expect_any_instance_of(Bosh::Cli::Command::User).to receive(:create).with("foo", "foo")
      expect(Bosh::Cli::Command::Login).to receive(:new).and_return(login_admin, login_foo)

      allow(microbosh_bootstrap).to receive(:ask).and_return("foo")
      microbosh_bootstrap.start
      microbosh_bootstrap.create_user("foo", "foo")
    end
  end
end
