require 'spec_helper'

describe Bosh::Aws::EC2 do
  let(:ec2) { described_class.new({}) }

  describe "elastic IPs" do
    describe "allocation" do
      it "can allocate a given number of elastic IPs" do
        fake_elastic_ip_collection = double("elastic_ips")
        ec2.stub(:aws_ec2).and_return(double("fake_aws_ec2", elastic_ips: fake_elastic_ip_collection))
        fake_elastic_ip_collection.stub(:allocate).and_return(double("elastic_ip").as_null_object)

        fake_elastic_ip_collection.should_receive(:allocate).with(vpc: true).exactly(5).times

        ec2.allocate_elastic_ips(5)
      end

      it "populates the elastic_ips variable with the newly created IPs" do
        fake_elastic_ip_collection = double("elastic_ips")
        ec2.stub(:aws_ec2).and_return(double("fake_aws_ec2", elastic_ips: fake_elastic_ip_collection))
        elastic_ip_1 = double("elastic_ip", public_ip: "1.2.3.4")
        elastic_ip_2 = double("elastic_ip", public_ip: "5.6.7.8")

        fake_elastic_ip_collection.stub(:allocate).and_return(elastic_ip_1, elastic_ip_2)

        ec2.elastic_ips.should == []

        ec2.allocate_elastic_ips(2)

        ec2.elastic_ips.should =~ ["1.2.3.4", "5.6.7.8"]
      end
    end

    describe "release" do
      it "can release the given IPs" do
        elastic_ip_1 = double("elastic_ip", public_ip: "1.2.3.4")
        elastic_ip_2 = double("elastic_ip", public_ip: "5.6.7.8")
        fake_aws_ec2 = double("aws_ec2", elastic_ips: [elastic_ip_1, elastic_ip_2])

        ec2.stub(:aws_ec2).and_return(fake_aws_ec2)

        elastic_ip_1.should_receive :release
        elastic_ip_2.should_not_receive :release

        ec2.release_elastic_ips ["1.2.3.4"]
      end

      it "can release all IPs" do
        instance_1 = double("instance", id: "i-test", api_termination_disabled?: false)
        elastic_ip_1 = double("elastic_ip", public_ip: "1.2.3.4", instance_id: nil)
        elastic_ip_2 = double("elastic_ip", public_ip: "5.6.7.8", instance_id: "i-test")
        fake_aws_ec2 = double("aws_ec2", elastic_ips: [elastic_ip_1, elastic_ip_2])

        ec2.should_receive(:terminatable_instances).and_return([instance_1])

        ec2.stub(:aws_ec2).and_return(fake_aws_ec2)

        elastic_ip_1.should_receive :release
        elastic_ip_2.should_receive :release

        ec2.release_all_elastic_ips
      end

      it "should not release an IP associated to a termination protected instance" do
        elastic_ip_1 = double("elastic_ip", public_ip: "1.2.3.4", instance_id: nil)
        elastic_ip_2 = double("elastic_ip", public_ip: "5.6.7.8", instance_id: "i-test")
        fake_aws_ec2 = double("aws_ec2", elastic_ips: [elastic_ip_1, elastic_ip_2])

        ec2.should_receive(:terminatable_instances).and_return([])

        ec2.stub(:aws_ec2).and_return(fake_aws_ec2)

        elastic_ip_1.should_receive :release
        elastic_ip_2.should_not_receive :release

        ec2.release_all_elastic_ips
      end
    end
  end

  describe "instances" do
    before do
      Bosh::AwsCloud::ResourceWait.stub(:for_instance)
    end

    describe "termination" do
      it "should terminate all instances and wait until completed before returning" do
        instance_1 = double("instance", api_termination_disabled?: false)
        instance_2 = double("instance", api_termination_disabled?: false)
        instance_3 = double("instance", api_termination_disabled?: true)
        fake_aws_ec2 = double("aws_ec2", instances: [instance_1, instance_2, instance_3])

        ec2.stub(:aws_ec2).and_return(fake_aws_ec2)
        ec2.stub(:sleep)

        instance_1.should_receive :terminate
        instance_2.should_receive :terminate
        instance_3.should_not_receive :terminate
        instance_1.should_receive(:status).and_return(:shutting_down, :shutting_down, :terminated, :terminated)
        instance_2.should_receive(:status).and_return(:shutting_down, :terminated, :terminated, :terminated)

        ec2.terminate_instances
      end
    end

    describe "listing names" do
      it "should list the names of all terminatable instances" do
        instance_1 = double("instance", instance_id: "id_1", tags: {"Name" => "instance1"}, api_termination_disabled?: false, status: :running)
        instance_2 = double("instance", instance_id: "id_2", tags: {"Name" => "instance2"}, api_termination_disabled?: false, status: :pending)
        instance_3 = double("instance", instance_id: "id_3", tags: {"Name" => "instance3"}, api_termination_disabled?: true, status: :running)
        instance_4 = double("instance", instance_id: "id_4", tags: {"Name" => "instance4"}, api_termination_disabled?: false, status: :terminated)
        instance_5 = double("instance", instance_id: "id_5", tags: {}, api_termination_disabled?: false, status: :running)
        fake_aws_ec2 = double("aws_ec2", instances: [instance_1, instance_2, instance_3, instance_4, instance_5])

        ec2.stub(:aws_ec2).and_return(fake_aws_ec2)

        ec2.instance_names.should == {"id_1" => "instance1", "id_2" => "instance2", "id_5" => "<unnamed instance>"}
      end
    end

    describe "#create_nat_instance" do
      subject(:create_nat_instance) do
        ec2.create_nat_instance(
            "name" => "name",
            "subnet_id" => "subnet_id",
            "ip" => "10.1.0.1",
            "security_group" => "sg",
            "key_name" => "bosh",
            "instance_type" => "m1.large"
        )
      end

      let(:fake_aws_client) { double(AWS::EC2::Client) }
      let(:nat_instance) { double(AWS::EC2::Instance, status: :running, id: 'i-123') }
      let(:instances) { double(AWS::EC2::InstanceCollection) }
      let(:fake_aws_ec2) { double(AWS::EC2, instances: instances, client: fake_aws_client) }
      let(:key_pair_1) { double(AWS::EC2::KeyPair, name: "bosh") }
      let(:key_pair_2) { double(AWS::EC2::KeyPair, name: "cf") }

      before do
        fake_aws_ec2.stub(:key_pairs).and_return([key_pair_1])
        ec2.stub(:aws_ec2).and_return(fake_aws_ec2)
        ec2.stub(:allocate_elastic_ip)
        nat_instance.stub(:associate_elastic_ip)
        nat_instance.stub(:add_tag)
        fake_aws_client.stub(:modify_instance_attribute)
        instances.stub(:create).and_return(nat_instance)
      end

      it "creates an instance with the given options and default NAT options" do
        instances.should_receive(:create).with(
           {
             subnet: "subnet_id",
             private_ip_address: "10.1.0.1",
             security_groups: ["sg"],
             key_name: "bosh",
             image_id: "ami-f619c29f",
             instance_type: "m1.large"
           }
        )

        create_nat_instance
      end

      it "should tag the NAT instance with a name" do
        nat_instance.should_receive(:add_tag).with("Name", {value: "name"})

        create_nat_instance
      end

      it "should associate an elastic IP to the NAT instance" do
        elastic_ip = mock('elastic_ip')

        ec2.should_receive(:allocate_elastic_ip).and_return(elastic_ip)
        nat_instance.should_receive(:associate_elastic_ip).with(elastic_ip)

        create_nat_instance
      end

      it "should retry to associate the elastic IP if elastic ip not yet allocated" do
        elastic_ip = mock('elastic_ip')

        ec2.should_receive(:allocate_elastic_ip).and_return(elastic_ip)

        nat_instance.
          should_receive(:associate_elastic_ip).
          with(elastic_ip).
          and_raise(AWS::EC2::Errors::InvalidAddress::NotFound)
        nat_instance.should_receive(:associate_elastic_ip).with(elastic_ip).and_return

        create_nat_instance
      end

      it "should disable source/destination checking for the NAT instance" do
        fake_aws_client.should_receive(:modify_instance_attribute).with(
           {
             instance_id: 'i-123',
             source_dest_check: {value: false}
           }
        )

        create_nat_instance
      end

      context "when no key pair name is given" do

        subject(:create_nat_instance_without_key_pair) do
          ec2.create_nat_instance(
              "name" => "name",
              "subnet_id" => "subnet_id",
              "ip" => "10.1.0.1",
              "security_group" => "sg"
          )
        end

        it "uses the key pair name on AWS if only one exists" do
          instances.should_receive(:create).with(
              {
                  subnet: "subnet_id",
                  private_ip_address: "10.1.0.1",
                  security_groups: ["sg"],
                  key_name: "bosh",
                  image_id: "ami-f619c29f",
                  instance_type: "m1.small"
              }
          )
          create_nat_instance_without_key_pair
        end

        it "raises an error if there is more than one key pair on AWS" do
          fake_aws_ec2.stub(:key_pairs).and_return([key_pair_1, key_pair_2])

          expect {
            create_nat_instance_without_key_pair
          }.to raise_error("AWS key pair name unspecified for instance 'name', " +
               "unable to select a default.")
        end

        it "raises an error if there is no key pair on AWS" do
          fake_aws_ec2.stub(:key_pairs).and_return([])

          expect {
            create_nat_instance_without_key_pair
          }.to raise_error("AWS key pair name unspecified for instance 'name', " +
               "no key pairs available to select a default.")
        end
      end

      context "when a key pair name is given" do
         it "raises an error if it doesn't exist on AWS" do
          fake_aws_ec2.stub(key_pairs: [key_pair_2])

          expect {
            create_nat_instance
          }.to raise_error("No such key pair 'bosh' on AWS.")
        end
      end
    end

    describe "#get_running_instance_by_name" do
      it "should get the instance by tagged name" do
        fake_aws_instance_1 = mock(AWS::EC2::Instance, tags: {"Name" => "foo"}, status: :running)
        fake_aws_instance_2 = mock(AWS::EC2::Instance, tags: {"Name" => "bar"}, status: :running)

        ec2.stub(:aws_ec2).and_return(mock("AWS::EC2", instances: [fake_aws_instance_1, fake_aws_instance_2]))

        ec2.get_running_instance_by_name("foo").should == fake_aws_instance_1
      end

      it "raises an error if more than one running instance has the given name" do
        fake_aws_instance_1 = mock(AWS::EC2::Instance, tags: {"Name" => "foo"}, status: :running)
        fake_aws_instance_2 = mock(AWS::EC2::Instance, tags: {"Name" => "foo"}, status: :running)

        ec2.stub(:aws_ec2).and_return(mock("AWS::EC2", instances: [fake_aws_instance_1, fake_aws_instance_2]))

        expect {
          ec2.get_running_instance_by_name("foo")
        }.to raise_error("More than one running instance with name 'foo'.")
      end
    end
  end

  describe "internet gateways" do
    describe "creating" do
      it "should create an internet gateway" do
        fake_gateway_collection = double("internet_gateways")
        fake_gateway = double(AWS::EC2::InternetGateway, id: 'igw-1234')
        ec2.stub(:aws_ec2).and_return(double("fake_aws_ec2", internet_gateways: fake_gateway_collection))
        fake_gateway_collection.should_receive(:create).and_return(fake_gateway)
        ec2.create_internet_gateway.should == fake_gateway
      end
    end

    describe "listing" do
      it "should return a list of internet gateway IDs" do
        ec2.stub(:aws_ec2).and_return(double("fake_aws_ec2", internet_gateways: [double("gw1", id: "gw1id"), double("gw2", id: "gw2id")]))
        ec2.internet_gateway_ids.should =~ ["gw1id", "gw2id"]
      end
    end

    describe "deleting" do
      it "should delete the internet gateways with the specified IDs" do
        fake_gateways = {
            "gw1" => double("fake gateway", attachments: [double("fake_attach")]),
            "gw2" => double("fake gateway", attachments: [double("fake_attach2"), double("fake_attach3")])
        }
        ec2.stub(:aws_ec2).and_return(double("fake_aws_ec2", internet_gateways: fake_gateways))
        fake_gateways.values.each do |gateway|
          gateway.should_receive :delete
          gateway.attachments.each { |a| a.should_receive(:delete) }
        end

        ec2.delete_internet_gateways ["gw1", "gw2"]
      end
    end
  end

  describe "key pairs" do
    let(:key_pairs) { double("key pairs") }
    let(:fake_aws_ec2) { double("aws_ec2", key_pairs: key_pairs) }
    let(:aws_key_pair) { double("key pair", name: "aws_key_pair") }

    before do
      ec2.stub(:aws_ec2).and_return(fake_aws_ec2)
      key_pairs.stub(:to_a).and_return([aws_key_pair], [])
    end

    describe "adding" do
      let(:public_key_path) { asset("id_spec_rsa.pub") }
      let(:private_key_path) { asset("id_spec_rsa") }

      describe "when the provided SSH key does not yet exist on the machine" do
        let(:public_key_path) { asset("id_new_rsa.pub") }
        let(:private_key_path) { asset("id_new_rsa") }

        before do
          key_pairs.stub(:import)
        end

        after(:each) do
          system "rm -f #{asset('id_new_rsa')}*"
        end

        it "should generate an SSH key when given a private_key_path" do
          File.should_not be_exist(public_key_path)
          File.should_not be_exist(private_key_path)
          ec2.add_key_pair("new_key_pair", private_key_path)
          File.should be_exist(public_key_path)
          File.should be_exist(private_key_path)
        end

        it "should generate an SSH key when given a public_key_path" do
          File.should_not be_exist(public_key_path)
          File.should_not be_exist(private_key_path)
          ec2.add_key_pair("new_key_pair", public_key_path)
          File.should be_exist(public_key_path)
          File.should be_exist(private_key_path)
        end
      end

      describe "when the key pair name exists on AWS" do

        context "adding forcibly" do
          it "should remove the key pair on AWS and add the local one" do
            aws_key_pair.should_receive :delete
            key_pairs.should_receive(:import).with("aws_key_pair", File.read(public_key_path))

            ec2.force_add_key_pair("aws_key_pair", public_key_path)
          end
        end

        context "adding normally" do
          it "should raise a nice error" do
            expect {
              ec2.add_key_pair("aws_key_pair", public_key_path)
            }.to raise_error(Bosh::Cli::CliError, /key pair aws_key_pair already exists on AWS/i)
          end
        end
      end

      it "should create an EC2 keypair with the correct name" do
        key_pairs.should_receive(:import).with("name", File.read(public_key_path))
        ec2.add_key_pair("name", public_key_path)
      end
    end

    describe "removing" do
      it "should remove the EC2 keypair if it exists" do
        aws_key_pair.should_receive(:delete)
        ec2.remove_key_pair("aws_key_pair")
      end

      it "should not attempt to remove a non-existent keypair" do
        expect {
          ec2.remove_key_pair("foobar")
        }.not_to raise_error
      end

      it "should remove all key pairs" do
        another_key_pair = double("key pair")
        fake_aws_ec2.stub(:key_pairs).and_return(
            [another_key_pair, aws_key_pair],
            []
        )

        aws_key_pair.should_receive :delete
        another_key_pair.should_receive :delete

        ec2.remove_all_key_pairs
      end
    end
  end

  describe "security groups" do
    let(:fake_vpc_sg) { double("security group", :name => "bosh", :vpc_id => "vpc-123") }
    let(:fake_default_sg) { double("security group", :name => "default", :vpc_id => false) }
    let(:fake_security_groups) { [fake_vpc_sg, fake_default_sg] }
    let(:fake_aws_ec2) { double("aws ec2", security_groups: fake_security_groups) }
    let(:ip_permissions) { double("ip permissions").as_null_object }

    before do
      ec2.stub(:aws_ec2).and_return(fake_aws_ec2)
    end

    describe "#security_group_in_use?" do
      it "should return false if no instances use it" do
        sg = mock("security group", :name => "sg", :instances => [])
        ec2.send(:security_group_in_use?, sg).should == false
      end

      it "should return false if no protected instances use it" do
        instance = mock("instance", :api_termination_disabled? => false)
        sg = mock("security group", :name => "sg", :instances => [instance])
        ec2.send(:security_group_in_use?, sg).should == false
      end

      it "should return true if a protected instances use it" do
        instance = mock("instance", :api_termination_disabled? => false)
        protected_instance = mock("instance", :api_termination_disabled? => true)
        sg = mock("security group", :name => "sg", :instances => [instance, protected_instance])
        ec2.send(:security_group_in_use?, sg).should == true
      end
    end

    describe "deleting" do
      it "should delete all" do
        fake_aws_ec2.should_receive(:security_groups)
        ec2.should_receive(:security_group_in_use?).and_return(false)
        fake_vpc_sg.should_receive(:ingress_ip_permissions).and_return(ip_permissions)
        fake_vpc_sg.should_receive(:egress_ip_permissions).and_return(ip_permissions)
        fake_vpc_sg.should_receive(:delete)
        ec2.should_receive(:security_group_in_use?).and_return(false)
        fake_default_sg.should_receive(:ingress_ip_permissions).and_return(ip_permissions)
        fake_default_sg.should_receive(:egress_ip_permissions).and_return(ip_permissions)
        fake_default_sg.should_not_receive(:delete)

        ec2.delete_all_security_groups
      end

      it "should not delete security groups in use" do
        fake_aws_ec2.should_receive(:security_groups)
        ec2.should_receive(:security_group_in_use?).and_return(true)
        fake_vpc_sg.should_not_receive(:ingress_ip_permissions)
        fake_vpc_sg.should_not_receive(:egress_ip_permissions)
        fake_vpc_sg.should_not_receive(:delete)
        ec2.should_receive(:security_group_in_use?).and_return(false)
        fake_default_sg.should_receive(:ingress_ip_permissions).and_return(ip_permissions)
        fake_default_sg.should_receive(:egress_ip_permissions).and_return(ip_permissions)
        fake_default_sg.should_not_receive(:delete)

        ec2.delete_all_security_groups
      end
    end
  end

  describe "deleting all EBS volumes" do
    let(:fake_aws_volumes) { double(AWS::EC2::VolumeCollection) }
    let(:fake_aws_ec2) { double(AWS::EC2, volumes: fake_aws_volumes) }
    let(:vol1) { double("vol1", attachments: []) }
    let(:vol2) { double("vol2", attachments: []) }
    let(:vol3) { double("vol3", attachments: ["something"]) }

    before do
      ec2.stub(:aws_ec2).and_return(fake_aws_ec2)
    end

    it "should delete all unattached volumes" do
      vol1.should_receive(:delete)
      vol2.should_receive(:delete)
      vol3.should_not_receive(:delete)
      fake_aws_volumes.should_receive(:filter).and_return([vol1, vol2, vol3])

      ec2.delete_volumes
    end
  end

  describe "#create_instance" do
    before do
      ec2.stub(:aws_ec2).and_return(fake_aws_ec2)
    end

    let(:fake_aws_ec2) { double("aws_ec2", :instances => mock("instances")) }
    it "should create an instance with the provided options" do
      fake_aws_ec2.instances.should_receive(:create).with({:some => "opts"})
      ec2.create_instance(:some => "opts")
    end
  end

  describe "#disable_src_dest_checking" do
    let(:ec2_client) { mock('client') }
    let(:fake_aws_ec2) { double("aws_ec2", :client => ec2_client) }

    it "should invoke the EC2 client to modify instance attributes" do
      ec2.stub(:aws_ec2).and_return(fake_aws_ec2)
      ec2_client.should_receive(:modify_instance_attribute).with({
                                                                     :instance_id => "i123",
                                                                     :source_dest_check => {:value => false}
                                                                 })
      ec2.disable_src_dest_checking("i123")
    end
  end
end
