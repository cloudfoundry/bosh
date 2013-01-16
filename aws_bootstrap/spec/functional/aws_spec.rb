require 'spec_helper'

describe Bosh::Cli::Command::AWS do
  before do
    ::AWS::EC2.stub(:new).as_null_object
  end

  describe "command line tools" do
    describe "aws create vpc" do
      let(:config_file) { asset "config.yml" }

      it "should create all the components of the vpc" do
        subject.should_receive(:create_vpc) do |args|
          args.keys.should =~ %w[domain tenancy cidr subnets dhcp_options elastic_ips security_groups]
        end
        subject.should_receive(:create_subnets).with [
          {"cidr" => "10.10.0.0/24", "availability_zone" => "us-east-1a"},
          {"cidr" => "10.10.1.0/24", "availability_zone" => "us-east-1b"}
        ]
        subject.should_receive(:create_dhcp_options).with(
          "domain_name" => "dev102.cf.com",
          "domain_name_servers" => ["10.10.0.5", "172.16.0.23"]
        )
        subject.should_receive(:create_security_groups) do |args|
          args.length.should == 2
          args.first.keys.should =~ %w[name ingress]
        end
        subject.should_receive(:allocate_elastic_ips).with 2
        subject.stub(:flush_output_state)

        subject.create config_file
      end

      it "should flush the output to a YAML file" do
        subject.should_receive(:flush_output_state) do |args|
          args.should match(/create-vpc-output-\d{14}.yml/)
        end
        subject.stub(:create_dhcp_options)
        subject.stub(:create_security_groups)
        subject.stub(:create_subnets)
        subject.stub(:create_vpc)
        subject.stub(:allocate_elastic_ips)

        subject.create config_file
      end

      context "when a step in the creation fails" do
        before do
          subject.stub(:create_vpc).and_raise
        end

        it "should still flush the output to a YAML so the user knows what resources were provisioned" do
          subject.should_receive(:flush_output_state) do |args|
            args.should match(/create-vpc-output-\d{14}.yml/)
          end

          expect {subject.create config_file}.to raise_error
        end
      end

      it "throws a nice error message when an invalid config file path is given" do
        expect {
          subject.create "badfilename"
        }.to raise_error(Bosh::Cli::CliError, "unable to read badfilename")
      end
    end

    describe "aws destroy vpc" do
      let(:output_file) { asset "test-output.yml" }

      it "should delete the vpc and all its dependencies, and release the elastic ips" do
        vpc = double("vpc", dhcp_options: double("dhcp_options"))

        subject.stub(:ec2).and_return(double("ec2", vpcs: {"vpc-13724979" => vpc}))
        vpc.stub(:instances).and_return([])

        subject.should_receive(:delete_security_groups)
        subject.should_receive(:delete_subnets)
        subject.should_receive(:delete_vpc)
        subject.should_receive(:release_elastic_ips)
        vpc.dhcp_options.should_receive(:delete)

        subject.delete output_file
      end

      context "when there are instances running" do
        it "throws a nice error message and doesn't delete any resources" do
          vpc = double("vpc", id: "vpc-13724979")

          subject.stub(:ec2).and_return(double("ec2", vpcs: {"vpc-13724979" => vpc}))
          vpc.stub(:instances).and_return([:running_instance])

          expect {
            subject.should_not_receive(:delete_security_groups)
            subject.delete output_file
          }.to raise_error(Bosh::Cli::CliError, "1 instance(s) running in vpc-13724979 - delete them first")
        end
      end

      it "throws a nice error message when an invalid details file path is given" do
        expect {
          subject.should_not_receive(:delete_security_groups)
          subject.delete "nonsense"
        }.to raise_error(Bosh::Cli::CliError, "unable to read nonsense")
      end
    end
  end
end
