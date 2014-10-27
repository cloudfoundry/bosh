require 'spec_helper'

describe Bosh::Aws::RDS do
  subject(:rds) { described_class.new({}) }
  let(:db_instance_1) { instance_double('AWS::RDS::DBInstance', name: 'bosh_db', id: "db1") }
  let(:db_instance_2) { instance_double('AWS::RDS::DBInstance', name: 'cc_db', id: "db2") }
  let(:fake_aws_rds) { instance_double('AWS::RDS', db_instances: [db_instance_1, db_instance_2]) }
  let(:fake_aws_rds_client) { instance_double('AWS::RDS::Client::V20130909') }

  before(:each) do
    AWS::RDS.stub(new: fake_aws_rds)
    AWS::RDS::Client.stub(new: fake_aws_rds_client)
  end

  describe "subnet_group_exists?" do
    it "should return false if the db subnet group does not exist" do
      fake_aws_rds_client.should_receive(:describe_db_subnet_groups).
          with(:db_subnet_group_name => "subnetgroup").
          and_raise AWS::RDS::Errors::DBSubnetGroupNotFoundFault

      rds.subnet_group_exists?("subnetgroup").should be(false)
    end

    it "should return true if the db subnet group exists" do
      fake_aws_rds_client.should_receive(:describe_db_subnet_groups).
          with(:db_subnet_group_name => "subnetgroup").
          and_return("not_used")

      rds.subnet_group_exists?("subnetgroup").should be(true)
    end
  end

  describe "create_database_subnet_group" do
    it "should create the RDS subnet group" do
      fake_aws_rds_client.should_receive(:create_db_subnet_group).
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

      fake_aws_rds_client.should_receive(:describe_db_subnet_groups).and_return(aws_response)
      rds.subnet_group_names.should == ["ccdb", "uaadb"]
    end
  end

  describe "delete_subnet_group" do
    it "should delete the subnet group" do
      fake_aws_rds_client.should_receive(:delete_db_subnet_group).with(:db_subnet_group_name => "ccdb")
      rds.delete_subnet_group("ccdb")
    end
  end

  describe "delete_subnet_groups" do
    it "should delete all the subnet groups" do
      rds.should_receive(:subnet_group_names).and_return(["ccdb", "uaadb"])
      rds.should_receive(:delete_subnet_group).with("ccdb")
      rds.should_receive(:delete_subnet_group).with("uaadb")
      rds.delete_subnet_groups
    end
  end

  describe "create_vpc_db_security_group" do
    let(:fake_vpc) { instance_double('Bosh::Aws::VPC', cidr_block: '1.2.3.4/0') }

    it "should delegate the VPC object to create a DB-friendly security group" do
      Bosh::Aws::VPC.stub(new: fake_vpc)

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
      fake_vpc.should_receive(:create_security_groups).with([expected_parameters])

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

      fake_aws_rds_client.should_receive(:describe_db_security_groups).and_return(aws_response)
      rds.security_group_names.should == ["default", "ccdb", "uaadb"]
    end
  end

  describe "delete_security_group" do
    it "should delete the security group" do
      fake_aws_rds_client.should_receive(:delete_db_security_group).with(:db_security_group_name => "ccdb")
      rds.delete_security_group("ccdb")
    end
  end

  describe "delete_security_groups" do
    it "should delete all the non-default security groups" do
      rds.should_receive(:security_group_names).and_return(["default", "ccdb", "uaadb"])
      # note: default is not included
      rds.should_receive(:delete_security_group).with("ccdb")
      rds.should_receive(:delete_security_group).with("uaadb")
      rds.delete_security_groups
    end
  end

  describe "creation" do
    let(:fake_response) { instance_double('AWS::Core::Response', data: { aws_key: "test_val" }) }
    let(:fake_aws_security_group) { instance_double('AWS::EC2::SecurityGroup', id: "sg-5678", name: "mydb") }
    let(:fake_aws_vpc) { instance_double('AWS::EC2::VPC', security_groups: [fake_aws_security_group]) }

    before(:each) do
      AWS::EC2::VPC.stub(new: fake_aws_vpc)
      fake_aws_rds_client.stub(:describe_db_subnet_groups).with(db_subnet_group_name: 'mydb').and_return(true)
      fake_aws_rds_client.stub(:describe_db_parameter_groups).with(db_parameter_group_name: 'utf8').and_return(true)
    end

    it "creates the utf8 db_parameter_group" do
      fake_aws_rds_client.should_receive(:describe_db_parameter_groups).
          with(:db_parameter_group_name => 'utf8').
          and_raise(AWS::RDS::Errors::DBParameterGroupNotFound)
      fake_aws_rds_client.should_receive(:create_db_parameter_group).
          with(:db_parameter_group_name => 'utf8',
               :db_parameter_group_family => 'mysql5.5',
               :description => 'utf8')

      fake_aws_rds_client.stub(:modify_db_parameter_group)
      fake_aws_rds_client.should_receive(:create_db_instance).and_return(fake_response)
      rds.create_database("mydb", ["subnet1", "subnet2"], "vpc-1234")
    end

    it "can create an RDS given a name" do
      generated_password = nil

      fake_aws_rds_client.should_receive(:create_db_instance) do |options|
        options[:db_instance_identifier].should == "mydb"
        options[:db_name].should == "mydb"
        options[:vpc_security_group_ids].should == ["sg-5678"]
        options[:allocated_storage].should == 5
        options[:db_instance_class].should == "db.m1.small"
        options[:engine].should == "mysql"
        options[:engine_version].should == "5.5.31"
        options[:db_parameter_group_name].should == "utf8"
        options[:master_username].should be_kind_of(String)
        options[:master_username].length.should be >= 8
        options[:master_user_password].should be_kind_of(String)
        options[:master_user_password].length.should be >= 16
        options[:db_subnet_group_name].should == "mydb"

        generated_password = options[:master_user_password]
        fake_response
      end

      # The contract is that create_database passes back the aws
      # response directly, but merges in the password that it generated.
      response = rds.create_database("mydb", ["subnet1", "subnet2"], "vpc-1234")

      response[:aws_key].should == "test_val"
      response[:master_user_password].should == generated_password
    end

    it "can create an RDS given a name and an optional parameter override" do
      fake_aws_rds_client.should_receive(:create_db_instance) do |options|
        options[:db_instance_identifier].should == "mydb"
        options[:db_name].should == "mydb"
        options[:vpc_security_group_ids].should == ["sg-5678"]
        options[:allocated_storage].should == 16
        options[:db_instance_class].should == "db.m1.small"
        options[:engine].should == "mysql"
        options[:engine_version].should == "5.5.31"
        options[:master_username].should be_kind_of(String)
        options[:master_username].length.should be >= 8
        options[:master_user_password].should == "swordfish"
        options[:db_subnet_group_name].should == "mydb"

        fake_response
      end

      rds.create_database("mydb", ["subnet1", "subnet2"], "vpc-1234", :allocated_storage => 16, :master_user_password => "swordfish")
    end

    context "when the subnet group doesn't exist" do
      it "should create the subnet group for the DB" do
        rds.should_receive(:subnet_group_exists?).with("mydb").and_return(false)

        fake_aws_rds_client.should_receive(:create_db_instance) do |options|
          options[:db_instance_identifier].should == "mydb"
          options[:db_name].should == "mydb"
          options[:vpc_security_group_ids].should == ["sg-5678"]
          options[:allocated_storage].should == 16
          options[:db_instance_class].should == "db.m1.small"
          options[:engine].should == "mysql"
          options[:master_username].should be_kind_of(String)
          options[:master_username].length.should be >= 8
          options[:master_user_password].should == "swordfish"
          options[:db_subnet_group_name].should == "mydb"

          fake_response
        end
        rds.should_receive(:create_subnet_group).with("mydb", ["subnet1", "subnet2"])

        rds.create_database("mydb", ["subnet1", "subnet2"], "vpc-1234", :allocated_storage => 16, :master_user_password => "swordfish")
      end
    end

    context "when the security group doesn't exist" do
      let(:bosh_aws_vpc) { instance_double('Bosh::Aws::VPC', cidr_block: '1.2.3.4/0')}

      before do
        bosh_aws_vpc.should_receive(:security_group_by_name).twice.and_return(nil, fake_aws_security_group)

        Bosh::Aws::VPC.stub(find: bosh_aws_vpc)
      end

      it "should create the security group for the DB" do
        fake_aws_rds_client.should_receive(:create_db_instance) do |options|
          options[:db_instance_identifier].should == "mydb"
          options[:db_name].should == "mydb"
          options[:vpc_security_group_ids].should == ["sg-5678"]
          options[:allocated_storage].should == 16
          options[:db_instance_class].should == "db.m1.small"
          options[:engine].should == "mysql"
          options[:master_username].should be_kind_of(String)
          options[:master_username].length.should be >= 8
          options[:master_user_password].should == "swordfish"
          options[:db_subnet_group_name].should == "mydb"

          fake_response
        end

        bosh_aws_vpc.should_receive(:create_security_groups).with(
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
      rds.databases.should == [db_instance_1, db_instance_2]
    end
  end

  describe "database_exists?" do
    it "should return true for an existing database" do
      rds.database_exists?("db2").should == true
    end

    it "should return false for an non-existent database" do
      rds.database_exists?("dbstupid").should == false
    end
  end

  describe "delete" do
    it "should delete all databases" do

      db_instance_1.stub(:db_instance_status)
      db_instance_2.stub(:db_instance_status)
      db_instance_1.should_receive(:delete).with(skip_final_snapshot: true)
      db_instance_2.should_receive(:delete).with(skip_final_snapshot: true)

      rds.delete_databases
    end

    it "should delete all databases but skip ones with status=deleting" do

      db_instance_1.stub(:db_instance_status).and_return("deleting")
      db_instance_2.stub(:db_instance_status)
      db_instance_1.should_not_receive(:delete)
      db_instance_2.should_receive(:delete).with(skip_final_snapshot: true)

      rds.delete_databases
    end
  end

  describe "database names" do
    it "provides a hash of db instance ids and their database names" do
      rds.database_names.should == {'db1' => 'bosh_db', 'db2' => 'cc_db'}
    end
  end
end
