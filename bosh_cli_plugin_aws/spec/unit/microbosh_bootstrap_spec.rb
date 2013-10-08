require "spec_helper"

describe Bosh::Aws::MicroBoshBootstrap do
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
        bootstrap.micro_ami.should == 'ami-tgupta'
      end
    end

    context "when the environment does not provide an override AMI" do
      before do
        Net::HTTP.should_receive(:get).with("bosh-jenkins-artifacts.s3.amazonaws.com", "/last_successful-bosh-stemcell-aws_ami_us-east-1").and_return("ami-david")
      end

      it "returns the content from S3" do
        bootstrap.micro_ami.should == "ami-david"
      end
    end
  end

  describe "deploying microbosh" do
    let(:microbosh_bootstrap) { described_class.new(nil, hm_director_account_options.merge(non_interactive: true)) }

    before do
      Bosh::Cli::Command::Micro.any_instance.stub(:micro_deployment)
      Bosh::Cli::Command::Micro.any_instance.stub(:perform)
      Bosh::Cli::Command::User.any_instance.stub(:create)
      Bosh::Cli::Command::Misc.any_instance.stub(:login)
      Bosh::Aws::MicroBoshBootstrap.any_instance.stub(:micro_ami).and_return("ami-123456")
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
      ::Bosh::Cli::Command::Base.any_instance.stub(:non_interactive?).and_return(true)
      File.exist?("deployments/micro/micro_bosh.yml").should == false
      microbosh_bootstrap.start
      File.exist?("deployments/micro/micro_bosh.yml").should == true
    end

    it "should remove any existing deployment artifacts first" do
      ::Bosh::Cli::Command::Base.any_instance.stub(:non_interactive?).and_return(true)
      FileUtils.mkdir_p("deployments/micro")
      File.open("deployments/bosh-registry.log", "w") { |f| f.write("old stuff!") }
      File.open("deployments/micro/leftover.yml", "w") { |f| f.write("old stuff!") }
      File.exist?("deployments/bosh-registry.log").should == true
      File.exist?("deployments/micro/leftover.yml").should == true
      microbosh_bootstrap.start
      File.exist?("deployments/bosh-registry.log").should == false
      File.exist?("deployments/micro/leftover.yml").should == false
    end

    it "should deploy a micro bosh" do
      ::Bosh::Cli::Command::Base.any_instance.stub(:non_interactive?).and_return(true)
      Bosh::Cli::Command::Micro.any_instance.should_receive(:micro_deployment).with("micro")
      Bosh::Cli::Command::Micro.any_instance.should_receive(:perform).with("ami-123456")
      microbosh_bootstrap.start
    end

    it "should login with admin/admin with non-interactive mode" do
      ::Bosh::Cli::Command::Base.any_instance.stub(:non_interactive?).and_return(true)
      Bosh::Cli::Command::Misc.any_instance.should_receive(:login).with("admin", "admin")
      microbosh_bootstrap.start
    end

    it "should login with created user with interactive mode" do
      misc_admin = double('Misc command for admin', :options= => nil)
      misc_foo = double('Misc command for foo', :options= => nil)

      misc_admin.should_receive(:login).with('admin', 'admin')
      misc_foo.should_receive(:login).with('foo', 'foo')

      Bosh::Cli::Command::User.any_instance.should_receive(:create).with("foo", "foo")
      Bosh::Cli::Command::Misc.should_receive(:new).and_return(misc_admin, misc_foo)

      microbosh_bootstrap.stub(:ask).and_return("foo")
      microbosh_bootstrap.start
      microbosh_bootstrap.create_user("foo", "foo")
    end
  end
end