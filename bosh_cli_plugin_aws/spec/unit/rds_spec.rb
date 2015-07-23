require 'spec_helper'

describe Bosh::AwsCliPlugin::RDS do
  subject(:rds) { described_class.new({}) }
  let(:db_instance_1) { instance_double('AWS::RDS::DBInstance', name: 'bosh_db', id: "db1") }
  let(:db_instance_2) { instance_double('AWS::RDS::DBInstance', name: 'cc_db', id: "db2") }
  let(:fake_aws_rds) { instance_double('AWS::RDS', db_instances: [db_instance_1, db_instance_2]) }
  let(:fake_aws_rds_client) { instance_double('AWS::RDS::Client::V20130909') }

  before(:each) do
    allow(AWS::RDS).to receive_messages(new: fake_aws_rds)
    allow(AWS::RDS::Client).to receive_messages(new: fake_aws_rds_client)
  end

  describe "subnet_group_exists?" do
    it "should return false if the db subnet group does not exist" do
      expect(fake_aws_rds_client).to receive(:describe_db_subnet_groups).
          with(:db_subnet_group_name => "subnetgroup").
          and_raise AWS::RDS::Errors::DBSubnetGroupNotFoundFault

      expect(rds.subnet_group_exists?("subnetgroup")).to be(false)
    end

    it "should return true if the db subnet group exists" do
      expect(fake_aws_rds_client).to receive(:describe_db_subnet_groups).
          with(:db_subnet_group_name => "subnetgroup").
          and_return("not_used")

      expect(rds.subnet_group_exists?("subnetgroup")).to be(true)
    end
  end

  describe "create_database_subnet_group" do
    it "should create the RDS subnet group" do
      expect(fake_aws_rds_client).to receive(:create_db_subnet_group).
          with(:db_subnet_group_name => "somedb",
               :db_subnet_group_description => "somedb",
               :subnet_ids => ["id1", "id2"])

      rds.create_subnet_group("somedb", ["id1", "id2"])
    end
  end

  describe "subnet_group_names" do
    it "should return the subnet group names" do
      ccdb_subnet_info = {:db_subnet_group_name => "ccdb"}
      uaadb_subnet_info = {:db_subnet_group_name => "uaadb"}
      aws_response = double(:aws_response, :data => {:db_subnet_groups => [ccdb_subnet_info, uaadb_subnet_info]})

      expect(fake_aws_rds_client).to receive(:describe_db_subnet_groups).and_return(aws_response)
      expect(rds.subnet_group_names).to eq(["ccdb", "uaadb"])
    end
  end

  describe "delete_subnet_group" do
    it "should delete the subnet group" do
      expect(fake_aws_rds_client).to receive(:delete_db_subnet_group).with(:db_subnet_group_name => "ccdb")
      rds.delete_subnet_group("ccdb")
    end
  end

  describe "delete_subnet_groups" do
    it "should delete all the subnet groups" do
      expect(rds).to receive(:subnet_group_names).and_return(["ccdb", "uaadb"])
      expect(rds).to receive(:delete_subnet_group).with("ccdb")
      expect(rds).to receive(:delete_subnet_group).with("uaadb")
      rds.delete_subnet_groups
    end
  end

  describe "create_vpc_db_security_group" do
    let(:fake_vpc) { instance_double('Bosh::AwsCliPlugin::VPC', cidr_block: '1.2.3.4/0') }

    it "should delegate the VPC object to create a DB-friendly security group" do
      allow(Bosh::AwsCliPlugin::VPC).to receive_messages(new: fake_vpc)

      expected_parameters = {
          "name" => "seeseedeebee",
          "ingress" => [
              {
                  "ports" => 3306,
                  "protocol" => :tcp,
                  "sources" => "1.2.3.4/0"
              }
          ]
      }
      expect(fake_vpc).to receive(:create_security_groups).with([expected_parameters])

      rds.create_vpc_db_security_group(fake_vpc, "seeseedeebee")
    end
  end

  describe "security_group_names" do
    it "should return the subnet group names" do
      default_security_group_info = {:db_security_group_name => "default"}
      ccdb_security_group_info = {:db_security_group_name => "ccdb"}
      uaadb_security_group_info = {:db_security_group_name => "uaadb"}
      aws_response = double(:aws_response, :data => {:db_security_groups => [
          default_security_group_info, ccdb_security_group_info, uaadb_security_group_info]})

      expect(fake_aws_rds_client).to receive(:describe_db_security_groups).and_return(aws_response)
      expect(rds.security_group_names).to eq(["default", "ccdb", "uaadb"])
    end
  end

  describe "delete_security_group" do
    it "should delete the security group" do
      expect(fake_aws_rds_client).to receive(:delete_db_security_group).with(:db_security_group_name => "ccdb")
      rds.delete_security_group("ccdb")
    end
  end

  describe "delete_security_groups" do
    it "should delete all the non-default security groups" do
      expect(rds).to receive(:security_group_names).and_return(["default", "ccdb", "uaadb"])
      # note: default is not included
      expect(rds).to receive(:delete_security_group).with("ccdb")
      expect(rds).to receive(:delete_security_group).with("uaadb")
      rds.delete_security_groups
    end
  end

  describe "creation" do
    let(:fake_response) { instance_double('AWS::Core::Response', data: { aws_key: "test_val" }) }
    let(:fake_aws_security_group) { instance_double('AWS::EC2::SecurityGroup', id: "sg-5678", name: "mydb") }
    let(:fake_aws_vpc) { instance_double('AWS::EC2::VPC', security_groups: [fake_aws_security_group]) }

    before(:each) do
      allow(AWS::EC2::VPC).to receive_messages(new: fake_aws_vpc)
      allow(fake_aws_rds_client).to receive(:describe_db_subnet_groups).with(db_subnet_group_name: 'mydb').and_return(true)
      allow(fake_aws_rds_client).to receive(:describe_db_parameter_groups).with(db_parameter_group_name: 'utf8').and_return(true)
    end

    it "creates the utf8 db_parameter_group" do
      expect(fake_aws_rds_client).to receive(:describe_db_parameter_groups).
          with(:db_parameter_group_name => 'utf8').
          and_raise(AWS::RDS::Errors::DBParameterGroupNotFound)
      expect(fake_aws_rds_client).to receive(:create_db_parameter_group).
          with(:db_parameter_group_name => 'utf8',
               :db_parameter_group_family => 'mysql5.5',
               :description => 'utf8')

      allow(fake_aws_rds_client).to receive(:modify_db_parameter_group)
      expect(fake_aws_rds_client).to receive(:create_db_instance).and_return(fake_response)
      rds.create_database("mydb", ["subnet1", "subnet2"], "vpc-1234")
    end

    it "can create an RDS given a name" do
      generated_password = nil

      expect(fake_aws_rds_client).to receive(:create_db_instance) do |options|
        expect(options[:db_instance_identifier]).to eq("mydb")
        expect(options[:db_name]).to eq("mydb")
        expect(options[:vpc_security_group_ids]).to eq(["sg-5678"])
        expect(options[:allocated_storage]).to eq(5)
        expect(options[:db_instance_class]).to eq("db.m1.small")
        expect(options[:engine]).to eq("mysql")
        expect(options[:engine_version]).to eq("5.5.40a")
        expect(options[:db_parameter_group_name]).to eq("utf8")
        expect(options[:master_username]).to be_kind_of(String)
        expect(options[:master_username].length).to be >= 8
        expect(options[:master_user_password]).to be_kind_of(String)
        expect(options[:master_user_password].length).to be >= 16
        expect(options[:db_subnet_group_name]).to eq("mydb")

        generated_password = options[:master_user_password]
        fake_response
      end

      # The contract is that create_database passes back the aws
      # response directly, but merges in the password that it generated.
      response = rds.create_database("mydb", ["subnet1", "subnet2"], "vpc-1234")

      expect(response[:aws_key]).to eq("test_val")
      expect(response[:master_user_password]).to eq(generated_password)
    end

    it "can create an RDS given a name and an optional parameter override" do
      expect(fake_aws_rds_client).to receive(:create_db_instance) do |options|
        expect(options[:db_instance_identifier]).to eq("mydb")
        expect(options[:db_name]).to eq("mydb")
        expect(options[:vpc_security_group_ids]).to eq(["sg-5678"])
        expect(options[:allocated_storage]).to eq(16)
        expect(options[:db_instance_class]).to eq("db.m1.small")
        expect(options[:engine]).to eq("mysql")
        expect(options[:engine_version]).to eq("5.5.40a")
        expect(options[:master_username]).to be_kind_of(String)
        expect(options[:master_username].length).to be >= 8
        expect(options[:master_user_password]).to eq("swordfish")
        expect(options[:db_subnet_group_name]).to eq("mydb")

        fake_response
      end

      rds.create_database("mydb", ["subnet1", "subnet2"], "vpc-1234", :allocated_storage => 16, :master_user_password => "swordfish")
    end

    context "when the subnet group doesn't exist" do
      it "should create the subnet group for the DB" do
        expect(rds).to receive(:subnet_group_exists?).with("mydb").and_return(false)

        expect(fake_aws_rds_client).to receive(:create_db_instance) do |options|
          expect(options[:db_instance_identifier]).to eq("mydb")
          expect(options[:db_name]).to eq("mydb")
          expect(options[:vpc_security_group_ids]).to eq(["sg-5678"])
          expect(options[:allocated_storage]).to eq(16)
          expect(options[:db_instance_class]).to eq("db.m1.small")
          expect(options[:engine]).to eq("mysql")
          expect(options[:master_username]).to be_kind_of(String)
          expect(options[:master_username].length).to be >= 8
          expect(options[:master_user_password]).to eq("swordfish")
          expect(options[:db_subnet_group_name]).to eq("mydb")

          fake_response
        end
        expect(rds).to receive(:create_subnet_group).with("mydb", ["subnet1", "subnet2"])

        rds.create_database("mydb", ["subnet1", "subnet2"], "vpc-1234", :allocated_storage => 16, :master_user_password => "swordfish")
      end
    end

    context "when the security group doesn't exist" do
      let(:bosh_aws_vpc) { instance_double('Bosh::AwsCliPlugin::VPC', cidr_block: '1.2.3.4/0')}

      before do
        expect(bosh_aws_vpc).to receive(:security_group_by_name).twice.and_return(nil, fake_aws_security_group)

        allow(Bosh::AwsCliPlugin::VPC).to receive_messages(find: bosh_aws_vpc)
      end

      it "should create the security group for the DB" do
        expect(fake_aws_rds_client).to receive(:create_db_instance) do |options|
          expect(options[:db_instance_identifier]).to eq("mydb")
          expect(options[:db_name]).to eq("mydb")
          expect(options[:vpc_security_group_ids]).to eq(["sg-5678"])
          expect(options[:allocated_storage]).to eq(16)
          expect(options[:db_instance_class]).to eq("db.m1.small")
          expect(options[:engine]).to eq("mysql")
          expect(options[:master_username]).to be_kind_of(String)
          expect(options[:master_username].length).to be >= 8
          expect(options[:master_user_password]).to eq("swordfish")
          expect(options[:db_subnet_group_name]).to eq("mydb")

          fake_response
        end

        expect(bosh_aws_vpc).to receive(:create_security_groups).with(
            [
                {
                    "name" => "mydb",
                    "ingress" => [
                        {
                            "ports" => 3306,
                            "sources" => "1.2.3.4/0",
                            "protocol" => :tcp,
                        },
                    ]
                },
            ]
        )

        rds.create_database("mydb", ["subnet1", "subnet2"], "vpc-1234", :allocated_storage => 16, :master_user_password => "swordfish")
      end
    end
  end

  describe "databases" do
    it "should return all databases" do
      expect(rds.databases).to eq([db_instance_1, db_instance_2])
    end
  end

  describe "database_exists?" do
    it "should return true for an existing database" do
      expect(rds.database_exists?("db2")).to eq(true)
    end

    it "should return false for an non-existent database" do
      expect(rds.database_exists?("dbstupid")).to eq(false)
    end
  end

  describe "delete" do
    it "should delete all databases" do

      allow(db_instance_1).to receive(:db_instance_status)
      allow(db_instance_2).to receive(:db_instance_status)
      expect(db_instance_1).to receive(:delete).with(skip_final_snapshot: true)
      expect(db_instance_2).to receive(:delete).with(skip_final_snapshot: true)

      rds.delete_databases
    end

    it "should delete all databases but skip ones with status=deleting" do

      allow(db_instance_1).to receive(:db_instance_status).and_return("deleting")
      allow(db_instance_2).to receive(:db_instance_status)
      expect(db_instance_1).not_to receive(:delete)
      expect(db_instance_2).to receive(:delete).with(skip_final_snapshot: true)

      rds.delete_databases
    end
  end

  describe "database names" do
    it "provides a hash of db instance ids and their database names" do
      expect(rds.database_names).to eq({'db1' => 'bosh_db', 'db2' => 'cc_db'})
    end
  end
end
