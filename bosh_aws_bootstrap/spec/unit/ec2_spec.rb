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

    describe "#snapshot_volume" do
      let(:fake_volume) { mock("ebs volume") }

      it "can snapshot a volume" do
        fake_volume.should_receive(:create_snapshot).with("description")
        ec2.stub(:tag)

        ec2.snapshot_volume(fake_volume, "snapshot name", "description", {})
      end

      it "tags the snapshot with a snapshot name" do
        fake_snapshot = mock("ebs snapshot")
        fake_volume.stub(:create_snapshot).and_return(fake_snapshot)

        fake_snapshot.should_receive(:add_tag).with('Name', :value => "snapshot name")

        ec2.snapshot_volume(fake_volume, "snapshot name", "description", {})
      end

      it "tags the snapshot with a list of tags" do
        fake_snapshot = mock("ebs snapshot")
        fake_volume.stub(:create_snapshot).and_return(fake_snapshot)

        fake_snapshot.should_receive(:add_tag).exactly(3).times

        ec2.snapshot_volume(fake_volume, "snapshot name", "description", {"tag1" => "value1", "tag2" => "value2"})
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
    describe "adding" do
      let(:fake_aws_ec2) { double("aws_ec2", key_pairs: double("key_pairs", import: nil)) }
      let(:public_key_path) { asset("id_spec_rsa.pub") }
      let(:private_key_path) { asset("id_spec_rsa") }

      before do
        ec2.stub(:aws_ec2).and_return(fake_aws_ec2)
      end

      describe "when the provided SSH key does not yet exist on the machine" do
        let(:public_key_path) { asset("id_new_rsa.pub") }
        let(:private_key_path) { asset("id_new_rsa") }

        after(:each) do
          system "rm -f #{asset('id_new_rsa')}*"
        end

        it "should generate an SSH key when given a private_key_path" do
          File.should_not be_exist(public_key_path)
          File.should_not be_exist(private_key_path)
          ec2.add_key_pair("name", private_key_path)
          File.should be_exist(public_key_path)
          File.should be_exist(private_key_path)
        end

        it "should generate an SSH key when given a public_key_path" do
          File.should_not be_exist(public_key_path)
          File.should_not be_exist(private_key_path)
          ec2.add_key_pair("name", public_key_path)
          File.should be_exist(public_key_path)
          File.should be_exist(private_key_path)
        end
      end

      describe "when the key pair name exists on AWS" do
        it "should raise a nice error" do
          fake_aws_ec2.key_pairs.stub(:import).and_raise(AWS::EC2::Errors::InvalidKeyPair::Duplicate)

          expect {
            ec2.add_key_pair("name", public_key_path)
          }.to raise_error(Bosh::Cli::CliError, /key pair name already exists on AWS/i)
        end
      end

      it "should create an EC2 keypair with the correct name" do
        fake_aws_ec2.key_pairs.should_receive(:import).with("name", File.read(public_key_path))
        ec2.add_key_pair("name", public_key_path)
      end
    end

    describe "removing" do
      let(:key_pair) { double("key pair") }
      let(:fake_aws_ec2) { double("aws_ec2", key_pairs: {"name" => key_pair}) }

      before do
        ec2.stub(:aws_ec2).and_return(fake_aws_ec2)
      end

      it "should remove the EC2 keypair if it exists" do
        key_pair.should_receive(:delete)
        ec2.remove_key_pair("name")
      end

      it "should not attempt to remove a non-existent keypair" do
        key_pair.should_not_receive(:delete)
        ec2.remove_key_pair("foobar")
      end
    end

    describe "removing all" do
      let(:fake_key_pair1) { double("key pair") }
      let(:fake_key_pair2) { double("key pair") }
      let(:fake_key_pairs) { [fake_key_pair1, fake_key_pair2] }
      let(:fake_aws_ec2) { double("aws ec2", key_pairs: fake_key_pairs) }

      before do
        ec2.stub(:aws_ec2).and_return(fake_aws_ec2)
      end

      it "should remove all key pairs" do
        ec2.should_receive(:key_pair_in_use?).and_return(false)
        fake_key_pair1.should_receive(:delete)
        ec2.should_receive(:key_pair_in_use?).and_return(false)
        fake_key_pair2.should_receive(:delete)
        ec2.remove_all_key_pairs
      end

      it "should not remove a key pair in use" do
        ec2.should_receive(:key_pair_in_use?).and_return(false)
        fake_key_pair1.should_receive(:delete)
        ec2.should_receive(:key_pair_in_use?).and_return(true)
        fake_key_pair2.should_not_receive(:delete)
        ec2.remove_all_key_pairs
      end
    end
  end

  describe "security groups" do
    let (:fake_vpc_sg) {double("security group", :name => "bosh", :vpc_id => "vpc-123")}
    let (:fake_default_sg) {double("security group", :name => "default", :vpc_id => false)}
    let (:fake_security_groups) {[fake_vpc_sg, fake_default_sg]}
    let (:fake_aws_ec2) {double("aws ec2", security_groups: fake_security_groups)}
    let (:ip_permissions) {double("ip permissions").as_null_object}

    before do
      ec2.stub(:aws_ec2).and_return(fake_aws_ec2)
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
    let(:fake_aws_ec2) { double("aws_ec2") }
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
      fake_aws_ec2.should_receive(:volumes).and_return([vol1, vol2, vol3])

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
