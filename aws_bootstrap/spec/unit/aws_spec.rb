require "spec_helper"
require "tmpdir"

describe Bosh::Cli::Command::AWS do
  def mock_ec2
    ec2 = double("ec2")
    yield ec2 if block_given?
    AWS::EC2.stub(:new).and_return(ec2)
  end

  let(:aws) { Bosh::Cli::Command::AWS.new }

  describe "vpc" do
    let(:vpcs) { double("vpcs") }
    let(:vpc) { double("vpc", :id => "vpc-xxxxxxxx") }
    let(:instances) { double("instances")}

    before do
      mock_ec2 do |ec2|
        vpc.stub(:instances).and_return(instances)
        vpcs.stub(:[]).with("vpc-xxxxxxxx").and_return(vpc)
        ec2.stub(:vpcs => vpcs)
      end
    end

    context "create" do
      it "should create a vpc" do
        vpcs.should_receive(:create).with("1.0.0.0/16", {}).and_return(vpc)

        aws.setup_ec2({})

        aws.create_vpc({"cidr" => "1.0.0.0/16"})

        aws.output_state["vpc"]["id"].should == "vpc-xxxxxxxx"
      end
    end

    context "delete" do
      it "should delete a vpc" do
        vpc.should_receive(:delete)

        aws.setup_ec2({})
        aws.vpc = vpc

        aws.delete_vpc
      end

      it "should throw an informative message if deletion fails" do
        vpc.should_receive(:delete).and_raise(AWS::EC2::Errors::DependencyViolation)

        aws.setup_ec2({})
        aws.vpc = vpc

        expect { aws.delete_vpc }.to raise_error("vpc-xxxxxxxx has dependencies that this tool does not delete")
      end
    end
  end

  describe "elastic IPs" do
    context "allocation" do
      it "should allocate elastic IPs" do
        mock_ec2 do |ec2|
          eip = double("elastic_ip", :public_ip => "1.2.3.4")
          elastic_ips = double("elastic_ips")
          elastic_ips.should_receive(:allocate).with(:vpc => true).exactly(5).times.and_return(eip)
          ec2.stub(:elastic_ips => elastic_ips)
        end

        aws.setup_ec2({})
        aws.allocate_elastic_ips(5)
        aws.output_state.should have_key("elastic_ips")
        aws.output_state["elastic_ips"].size.should == 5
        aws.output_state["elastic_ips"].first.should == "1.2.3.4"
      end
    end

    context "release" do
      it "should release the given ips" do
        mock_ec2 do |ec2|
          elastic_ip_1 = double("elastic_ip", public_ip: "1.2.3.4")
          elastic_ip_2 = double("elastic_ip", public_ip: "5.6.7.8")

          ec2.should_receive(:elastic_ips).and_return [elastic_ip_1, elastic_ip_2]

          elastic_ip_1.should_receive(:release)
          elastic_ip_2.should_not_receive(:release)
        end

        aws.setup_ec2({})
        aws.release_elastic_ips(["1.2.3.4"])
      end
    end
  end

  describe "subnets" do

    context "create" do
      it "should be created without az if az is absent" do
        subnets = double("subnets")
        subnets.should_receive(:create).with("1.0.10.0/24", {})

        mock_ec2

        aws.setup_ec2({})
        aws.stub(:vpc).and_return(double("vpc", :id => "vpc-xxxxxxxx", :subnets => subnets))
        aws.create_subnets([{"cidr" => "1.0.10.0/24"}])
      end

      it "should be created with az if az is present" do
        subnets = double("subnets")
        subnets.should_receive(:create).with("1.0.10.0/24", {:availability_zone => "us-east-1"})

        mock_ec2

        aws.setup_ec2({})
        aws.vpc = double("vpc", :id => "vpc-xxxxxxxx", :subnets => subnets)
        aws.create_subnets([{"cidr" => "1.0.10.0/24", "availability_zone" => "us-east-1"}])
      end
    end

    context "delete" do
      it "should delete all subnets" do
        subnet = double("subnet")
        aws.vpc = double("vpc", subnets: [subnet])

        subnet.should_receive(:delete)

        aws.delete_subnets
      end
    end
  end

  describe "dhcp_options" do

    context "create" do
      it "should create dhcp_options" do
        mock_ec2 do |ec2|
          dhcp_options = double("dhcp", id: "dhcp_id")
          dhcp_options.should_receive(:associate).with("vpc-xxxxxxxx")
          ec2.stub(:dhcp_options => as_null_object)
          ec2.dhcp_options.should_receive(:create).with({}).and_return(dhcp_options)
        end

        aws.setup_ec2({})
        aws.vpc = double("vpc", id: "vpc-xxxxxxxx", dhcp_options: double.as_null_object)
        aws.create_dhcp_options({})
      end

      it "should delete the default dhcp options" do
        default_dhcp_options = double("dhcp_options", id: "dhcp_id")
        default_dhcp_options.should_receive(:delete)

        mock_ec2 do |ec2|
          ec2.stub_chain(:dhcp_options, :create).and_return(double.as_null_object)
        end

        aws.setup_ec2({})
        aws.vpc = double("vpc", id: "vpc-xxxxxxxx", dhcp_options: default_dhcp_options)

        aws.create_dhcp_options({})
      end
    end
  end

  describe "security groups" do

    context "create" do
      before do
        mock_ec2
      end

      let(:security_groups) { double("security_groups") }
      let(:security_group) { double("security_group") }

      def create_security_groups (ingress_rules)
        aws.setup_ec2({})
        aws.vpc = double("vpc", :id => "vpc-xxxxxxxx", :security_groups => security_groups)

        aws.create_security_groups [
                                       "name" => "sg",
                                       "ingress" => ingress_rules
                                   ]
      end

      it "should be created" do
        security_groups.stub(:each)

        security_group.should_receive(:authorize_ingress).with(:tcp, 22, "1.2.3.0/24")
        security_group.should_receive(:authorize_ingress).with(:tcp, 23, "1.2.4.0/24")
        security_groups.should_receive(:create).with("sg").and_return(security_group)

        create_security_groups [
                                   {"protocol" => :tcp, "ports" => 22, "sources" => "1.2.3.0/24"},
                                   {"protocol" => :tcp, "ports" => 23, "sources" => "1.2.4.0/24"}
                               ]
      end

      it "should delete unused existing security group on create" do
        security_group.stub(:delete)

        security_group.should_receive(:authorize_ingress).with(:tcp, 22, "1.2.3.0/24")
        security_group.should_receive(:name).and_return("sg")
        security_groups.should_receive(:each).and_yield(security_group)
        security_groups.should_receive(:create).with("sg").and_return(security_group)

        create_security_groups [
                                   {"protocol" => :tcp, "ports" => 22, "sources" => "1.2.3.0/24"}
                               ]
      end

      it "should not delete existing security group if in use" do
        security_group.should_receive(:name).and_return("sg")
        security_group.should_receive(:delete).and_raise(::AWS::EC2::Errors::DependencyViolation)
        security_groups.should_receive(:each).and_yield(security_group)
        security_groups.should_not_receive(:create)

        create_security_groups [
                                   {"protocol" => :tcp, "ports" => 22, "sources" => "1.2.3.0/24"}
                               ]
      end
    end

    context "delete" do
      it "should delete all security groups except the default one" do
        default_security_group = double("security_group", name: "default")
        created_security_group = double("security_group", name: "created")
        aws.vpc = double("vpc", security_groups: [default_security_group, created_security_group])

        default_security_group.should_not_receive(:delete)
        created_security_group.should_receive(:delete)

        aws.delete_security_groups
      end
    end
  end

  describe "output state" do

    before do
      @config_dir = Dir.mktmpdir
    end

    after do
      FileUtils.rm_rf(@config_dir)
    end

    it "should be flushable" do
      aws.setup_ec2(foo: :bar)

      file_path = File.join(@config_dir, "foo")

      aws.flush_output_state(file_path)

      output = YAML.load_file(file_path)
      output['aws'].should == {foo: :bar}
    end
  end
end
