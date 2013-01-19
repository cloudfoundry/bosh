require 'spec_helper'

describe Bosh::Aws::VPC do
  describe "VPC" do
    describe "creation" do
      it "can create a VPC given a cidr and instance_tenancy" do
        fake_vpc_collection = mock("vpcs")
        fake_ec2 = mock("ec2", vpcs: fake_vpc_collection)

        fake_vpc_collection.
            should_receive(:create).
            with("cider", {instance_tenancy: "house rules"}).
            and_return(mock("aws_vpc", id: "vpc-1234567"))

        described_class.create(fake_ec2, "cider", "house rules").vpc_id.should == "vpc-1234567"
      end
    end

    describe "find" do
      it "can find a VPC with vpc_id" do
        fake_vpc_collection = mock("vpcs")
        fake_ec2 = mock("ec2", vpcs: fake_vpc_collection)

        fake_vpc_collection.should_receive(:[]).with("vpc-1234567").and_return(mock("aws_vpc", id: "vpc-1234567"))

        described_class.find(fake_ec2, "vpc-1234567").vpc_id.should == "vpc-1234567"
      end
    end

    describe "deletion" do
      it "can delete the VPC" do
        fake_aws_vpc = mock("aws_vpc")
        fake_aws_vpc.should_receive :delete

        Bosh::Aws::VPC.new(mock('ec2'), fake_aws_vpc).delete_vpc
      end

      it "throws a nice error message when unable to delete the VPC" do
        fake_aws_vpc = mock("aws_vpc", id: "boshIsFun")

        fake_aws_vpc.should_receive(:delete).and_raise(::AWS::EC2::Errors::DependencyViolation)

        expect {
          Bosh::Aws::VPC.new(mock('ec2'), fake_aws_vpc).delete_vpc
        }.to raise_error("boshIsFun has dependencies that this tool does not delete")
      end
    end
  end

  describe "subnets" do
    describe "creation" do
      it "can create subnets with the specified CIDRs and, optionally, AZs" do
        subnet_1_specs = {"cidr" => "cider", "availability_zone" => "canada"}
        subnet_2_specs = {"cidr" => "cedar"}

        fake_aws_vpc = mock("aws_vpc", subnets: mock("subnets"))

        fake_aws_vpc.subnets.should_receive(:create).with("cider", {availability_zone: "canada"})
        fake_aws_vpc.subnets.should_receive(:create).with("cedar", {})

        Bosh::Aws::VPC.new(mock('ec2'), fake_aws_vpc).create_subnets([subnet_1_specs, subnet_2_specs])
      end
    end

    describe "deletion" do
      it "can delete all subnets of a VPC" do
        fake_aws_vpc = mock("ec2_vpc", subnets: [mock("subnet")])

        fake_aws_vpc.subnets.each { |subnet| subnet.should_receive :delete }

        Bosh::Aws::VPC.new(mock('ec2'), fake_aws_vpc).delete_subnets
      end
    end
  end

  describe "security groups" do
    describe "creation" do
      let(:security_groups) { double("security_groups") }
      let(:security_group) { double("security_group") }

      it "should be created" do
        security_groups.stub(:create).with("sg").and_return(security_group)
        security_groups.stub(:each)

        security_group.should_receive(:authorize_ingress).with(:tcp, 22, "1.2.3.0/24")
        security_group.should_receive(:authorize_ingress).with(:tcp, 23, "1.2.4.0/24")

        ingress_rules = [
            {"protocol" => :tcp, "ports" => 22, "sources" => "1.2.3.0/24"},
            {"protocol" => :tcp, "ports" => 23, "sources" => "1.2.4.0/24"}
        ]
        Bosh::Aws::VPC.new(mock("ec2"), mock("aws_vpc", security_groups: security_groups)).
            create_security_groups ["name" => "sg", "ingress" => ingress_rules]
      end

      it "should delete unused existing security group on create" do
        existing_security_group = mock("security_group", name: "sg")

        security_group.stub(:authorize_ingress).with(:tcp, 22, "1.2.3.0/24")
        security_groups.stub(:create).with("sg").and_return(security_group)
        security_groups.stub(:each).and_yield(existing_security_group)

        existing_security_group.should_receive :delete

        ingress_rules = [
            {"protocol" => :tcp, "ports" => 22, "sources" => "1.2.3.0/24"}
        ]
        Bosh::Aws::VPC.new(mock("ec2"), mock("aws_vpc", security_groups: security_groups)).
            create_security_groups ["name" => "sg", "ingress" => ingress_rules]
      end

      it "should not delete existing security group if in use" do
        existing_security_group = mock("security_group", name: "sg")

        security_groups.stub(:each).and_yield(existing_security_group)
        existing_security_group.stub(:delete).and_raise(::AWS::EC2::Errors::DependencyViolation)

        security_groups.should_not_receive(:create)

        ingress_rules = [
            {"protocol" => :tcp, "ports" => 22, "sources" => "1.2.3.0/24"}
        ]
        Bosh::Aws::VPC.new(mock("ec2"), mock("aws_vpc", security_groups: security_groups)).
            create_security_groups ["name" => "sg", "ingress" => ingress_rules]
      end
    end

    describe "deletion" do
      it "can delete all security groups of a vpc except the default one" do
        fake_default_group = mock("security_group", name: "default")
        fake_special_group = mock("security_group", name: "special")

        fake_special_group.should_receive :delete
        fake_default_group.should_not_receive :delete

        Bosh::Aws::VPC.new(mock('ec2'), mock("aws_vpc", security_groups: [fake_default_group, fake_special_group])).
            delete_security_groups
      end
    end
  end


  describe "dhcp_options" do
    describe "creation" do
      it "can create DHCP options" do
        fake_dhcp_option_collection = mock("dhcp options collection")
        fake_dhcp_options = mock("dhcp options")

        fake_dhcp_option_collection.should_receive(:create).with({}).and_return(fake_dhcp_options)
        fake_dhcp_options.should_receive(:associate).with("vpc-xxxxxxxx")

        Bosh::Aws::VPC.new(
            mock('ec2', dhcp_options: fake_dhcp_option_collection),
            mock("aws_vpc", id: "vpc-xxxxxxxx", dhcp_options: double("default dhcp options").as_null_object)
        ).create_dhcp_options({})
      end

      it "can delete the default DHCP options" do
        fake_dhcp_option_collection = mock("dhcp options collection")
        fake_default_dhcp_options = double("default dhcp options")

        fake_dhcp_option_collection.stub(:create).and_return(double("dhcp options").as_null_object)

        fake_default_dhcp_options.should_receive :delete

        Bosh::Aws::VPC.new(
            mock('ec2', dhcp_options: fake_dhcp_option_collection),
            mock("aws_vpc", id: "vpc-xxxxxxxx", dhcp_options: fake_default_dhcp_options)
        ).create_dhcp_options({})
      end
    end
  end
end