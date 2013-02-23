require 'spec_helper'

describe Bosh::Aws::RDS do
  let(:rds) { described_class.new({}) }
  let(:db_instance_1) { double("database instance", name: 'bosh_db', id: "db1") }
  let(:db_instance_2) { double("database instance", name: 'cc_db', id: "db2") }
  let(:fake_aws_rds) { double("aws_rds", db_instances: [db_instance_1, db_instance_2]) }

  before(:each) do
    rds.stub(:aws_rds).and_return(fake_aws_rds)
  end

  describe "subnet_group_exists?" do
    let(:fake_aws_rds_client) { mock("aws_rds_client") }

    before(:each) do
      rds.stub(:aws_rds_client).and_return(fake_aws_rds_client)
    end

    it "should return false if the db subnet group does not exist" do
      fake_aws_rds_client.should_receive(:describe_db_subnet_groups).
        with(:db_subnet_group_name => "subnetgroup").
        and_raise AWS::RDS::Errors::DBSubnetGroupNotFoundFault

      rds.subnet_group_exists?("subnetgroup").should be_false
    end

    it "should return true if the db subnet group exists" do
      fake_aws_rds_client.should_receive(:describe_db_subnet_groups).
        with(:db_subnet_group_name => "subnetgroup").
        and_return("not_used")

      rds.subnet_group_exists?("subnetgroup").should be_true
    end
  end

  describe "create_database_subnet_group" do
    let(:fake_aws_rds_client) { mock("aws_rds_client") }

    before(:each) do
      rds.stub(:aws_rds_client).and_return(fake_aws_rds_client)
    end

    it "should create the RDS subnet group" do
      fake_aws_rds_client.should_receive(:create_db_subnet_group).
        with(:db_subnet_group_name => "somedb",
             :db_subnet_group_description => "somedb",
             :subnet_ids => ["id1", "id2"])

      rds.create_subnet_group("somedb", ["id1", "id2"])
    end
  end

  describe "creation" do
    let(:fake_aws_rds_client) { mock("aws_rds_client") }
    let(:fake_response) { mock("response", data: {:aws_key => "test_val"}) }

    before(:each) do
      rds.stub(:aws_rds_client).and_return(fake_aws_rds_client)
    end

    it "can create an RDS given a name" do
      generated_password = nil

      fake_aws_rds_client.should_receive(:create_db_instance) do |options|
        options[:db_instance_identifier].should == "mydb"
        options[:db_name].should == "mydb"
        options[:allocated_storage].should == 5
        options[:db_instance_class].should == "db.t1.micro"
        options[:engine].should == "mysql"
        options[:master_username].should be_kind_of(String)
        options[:master_username].length.should be >= 8
        options[:master_user_password].should be_kind_of(String)
        options[:master_user_password].length.should be >= 16
        options[:db_subnet_group_name].should == "mydb"

        generated_password = options[:master_user_password]
        fake_response
      end

      rds.should_receive(:subnet_group_exists?).with("mydb").and_return(true)

      # The contract is that create_database passes back the aws
      # response directly, but merges in the password that it generated.
      response = rds.create_database("mydb", ["subnet1", "subnet2"])
      response[:aws_key].should == "test_val"
      response[:master_user_password].should == generated_password
    end

    it "can create an RDS given a name and an optional parameter override" do
      fake_aws_rds_client.should_receive(:create_db_instance) do |options|
        options[:db_instance_identifier].should == "mydb"
        options[:db_name].should == "mydb"
        options[:allocated_storage].should == 16
        options[:db_instance_class].should == "db.t1.micro"
        options[:engine].should == "mysql"
        options[:master_username].should be_kind_of(String)
        options[:master_username].length.should be >= 8
        options[:master_user_password].should == "swordfish"
        options[:db_subnet_group_name].should == "mydb"

        fake_response
      end

      rds.should_receive(:subnet_group_exists?).with("mydb").and_return(true)
      rds.create_database("mydb", ["subnet1", "subnet2"], :allocated_storage => 16, :master_user_password => "swordfish")
    end

    it "should create the subnet group for the DB if it does not exist" do
      fake_aws_rds_client.should_receive(:create_db_instance) do |options|
        options[:db_instance_identifier].should == "mydb"
        options[:db_name].should == "mydb"
        options[:allocated_storage].should == 16
        options[:db_instance_class].should == "db.t1.micro"
        options[:engine].should == "mysql"
        options[:master_username].should be_kind_of(String)
        options[:master_username].length.should be >= 8
        options[:master_user_password].should == "swordfish"
        options[:db_subnet_group_name].should == "mydb"

        fake_response
      end

      rds.should_receive(:create_subnet_group).with("mydb", ["subnet1", "subnet2"])
      rds.should_receive(:subnet_group_exists?).with("mydb").and_return(false)
      rds.create_database("mydb", ["subnet1", "subnet2"], :allocated_storage => 16, :master_user_password => "swordfish")
    end
  end

  describe "databases" do
    it "should return all databases" do
      rds.databases.should == [db_instance_1, db_instance_2]
    end
  end

  describe "database_exists?" do
    it "should return true for an existing database" do
      rds.database_exists?("bosh_db").should == true
    end

    it "should return false for an non-existent database" do
      rds.database_exists?("oh_hai").should == false
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
