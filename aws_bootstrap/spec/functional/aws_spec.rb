require 'spec_helper'

describe Bosh::Cli::Command::AWS do
  let(:aws) { subject }

  describe "command line tools" do
    describe "aws create vpc" do
      let(:config_file) { asset "config.yml" }

      it "should create all the components of the vpc" do
        fake_ec2 = mock("ec2")
        fake_vpc = mock("vpc")
        fake_route53 = mock("route53")

        Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
        Bosh::Aws::VPC.stub(:create).with(fake_ec2, "10.10.0.0/16", "default").and_return(fake_vpc)
        Bosh::Aws::Route53.stub(:new).and_return(fake_route53)

        fake_vpc.stub(:vpc_id)

        fake_vpc.should_receive(:create_subnets).with [
                                                          {"cidr" => "10.10.0.0/24", "availability_zone" => "us-east-1a"},
                                                          {"cidr" => "10.10.1.0/24", "availability_zone" => "us-east-1b"}
                                                      ]
        fake_vpc.should_receive(:create_dhcp_options).with(
            "domain_name" => "dev102.cf.com",
            "domain_name_servers" => ["10.10.0.5", "172.16.0.23"]
        )
        fake_vpc.should_receive(:create_security_groups) do |args|
          args.length.should == 2
          args.first.keys.should =~ %w[name ingress]
        end
        fake_ec2.should_receive(:allocate_elastic_ips).with(2)

        fake_ec2.stub(:elastic_ips).and_return(["107.23.46.162", "107.23.53.76"])

        fake_vpc.stub(:flush_output_state)

        fake_route53.should_receive(:add_record).with("*", "dev102.cf.com", ["107.23.46.162", "107.23.53.76"])

        aws.create_vpc config_file
      end

      it "should flush the output to a YAML file" do
        fake_ec2 = mock("ec2")
        fake_vpc = mock("vpc")
        fake_route53 = mock("route53")

        Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
        Bosh::Aws::VPC.stub(:create).and_return(fake_vpc)
        Bosh::Aws::Route53.stub(:new).and_return(fake_route53)

        fake_vpc.stub(:vpc_id).and_return("vpc id")
        fake_vpc.stub(:create_dhcp_options)
        fake_vpc.stub(:create_security_groups)
        fake_vpc.stub(:create_subnets)
        fake_ec2.stub(:allocate_elastic_ips)
        fake_ec2.stub(:elastic_ips).and_return(["1.2.3.4", "5.6.7.8"])
        fake_route53.stub(:create_zone)
        fake_route53.stub(:add_record)

        aws.should_receive(:flush_output_state) do |args|
          args.should match(/create-vpc-output-\d{14}.yml/)
        end

        aws.create_vpc config_file

        aws.output_state["vpc"]["id"].should == "vpc id"
        aws.output_state["elastic_ips"]["router"]["ips"].should == ["1.2.3.4", "5.6.7.8"]
        aws.output_state["elastic_ips"]["router"]["dns_record"].should == "*"
      end

      context "when a step in the creation fails" do
        it "should still flush the output to a YAML so the user knows what resources were provisioned" do
          fake_vpc = mock("vpc")

          Bosh::Aws::EC2.stub(:new)
          Bosh::Aws::VPC.stub(:create).and_return(fake_vpc)
          fake_vpc.stub(:vpc_id).and_return("vpc id")
          fake_vpc.stub(:create_subnets).and_raise

          aws.should_receive(:flush_output_state) do |args|
            args.should match(/create-vpc-output-\d{14}.yml/)
          end

          expect { aws.create_vpc config_file }.to raise_error

          aws.output_state["vpc"]["id"].should == "vpc id"
        end
      end

      it "throws a nice error message when an invalid config file path is given" do
        expect {
          aws.create_vpc "badfilename"
        }.to raise_error(Bosh::Cli::CliError, "unable to read badfilename")
      end
    end

    describe "aws destroy vpc" do
      let(:output_file) { asset "test-output.yml" }

      it "should delete the vpc and all its dependencies, and release the elastic ips" do
        fake_ec2 = mock("ec2")
        fake_vpc = mock("vpc")
        fake_dhcp_options = mock("dhcp options")
        fake_route53 = mock("route53")

        Bosh::Aws::EC2.stub(:new).and_return(fake_ec2)
        Bosh::Aws::VPC.stub(:find).with(fake_ec2, "vpc-13724979").and_return(fake_vpc)
        Bosh::Aws::Route53.stub(:new).and_return(fake_route53)

        fake_vpc.stub(:dhcp_options).and_return(fake_dhcp_options)
        fake_vpc.stub(:instances_count).and_return(0)

        fake_vpc.should_receive :delete_security_groups
        fake_vpc.should_receive :delete_subnets
        fake_vpc.should_receive :delete_vpc
        fake_dhcp_options.should_receive :delete
        fake_ec2.should_receive(:release_elastic_ips).with ["107.23.46.162", "107.23.53.76"]

        fake_route53.should_receive(:delete_record).with("*", "cfdev.com")

        aws.delete_vpc output_file
      end

      context "when there are instances running" do
        it "throws a nice error message and doesn't delete any resources" do
          fake_vpc = mock("vpc")

          Bosh::Aws::EC2.stub(:new)
          Bosh::Aws::VPC.stub(:find).and_return(fake_vpc)

          fake_vpc.stub(:instances_count).and_return(1)
          fake_vpc.stub(:vpc_id).and_return("vpc-13724979")

          expect {
            fake_vpc.should_not_receive(:delete_security_groups)
            aws.delete_vpc output_file
          }.to raise_error(Bosh::Cli::CliError, "1 instance(s) running in vpc-13724979 - delete them first")
        end
      end

      it "throws a nice error message when an invalid details file path is given" do
        expect {
          Bosh::Aws::VPC.any_instance.should_not_receive(:delete_security_groups)
          aws.delete_vpc "nonsense"
        }.to raise_error(Bosh::Cli::CliError, "unable to read nonsense")
      end
    end

    describe "aws empty s3" do
      let(:config_file) { asset "config.yml" }

      it "should warn the user that the operation is destructive and list the buckets" do
        fake_s3 = mock("s3")

        Bosh::Aws::S3.stub(:new).and_return(fake_s3)
        fake_s3.stub(:bucket_names).and_return(["buckets of fun", "barrel of monkeys"])

        aws.should_receive(:say).with("THIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".red)
        aws.should_receive(:say).with("Buckets:\n\tbuckets of fun\n\tbarrel of monkeys")
        aws.should_receive(:agree).with("Are you sure you want to empty and delete all buckets?").and_return(false)

        aws.empty_s3 config_file
      end

      context "when the users agrees to nuke the buckets" do
        it "should empty and delete all S3 buckets associated with an account" do
          fake_s3 = mock("s3")

          Bosh::Aws::S3.stub(:new).and_return(fake_s3)
          fake_s3.stub(:bucket_names).and_return(double.as_null_object)

          aws.stub(:say).twice
          aws.stub(:agree).and_return(true)

          fake_s3.should_receive :empty

          aws.empty_s3 config_file
        end
      end

      context "when the user wants to bail out" do
        it "should not destroy the buckets" do
          fake_s3 = mock("s3")

          Bosh::Aws::S3.stub(:new).and_return(fake_s3)
          fake_s3.stub(:bucket_names).and_return(double.as_null_object)

          aws.stub(:say).twice
          aws.stub(:agree).and_return(false)

          fake_s3.should_not_receive :empty

          aws.empty_s3 config_file
        end
      end
    end
  end
end
