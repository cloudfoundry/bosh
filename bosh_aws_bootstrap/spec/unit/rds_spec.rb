require 'spec_helper'

describe Bosh::Aws::RDS do
  let(:rds) { described_class.new({}) }
  let(:db_instance_1) { double("database instance", name: 'bosh_db', id: "db1") }
  let(:db_instance_2) { double("database instance", name: 'cc_db', id: "db2") }
  let(:fake_aws_rds) { double("aws_rds", db_instances: [db_instance_1, db_instance_2]) }

  before(:each) do
    rds.stub(:aws_rds).and_return(fake_aws_rds)
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

        generated_password = options[:master_user_password]
        fake_response
      end

      # The contract is that create_database passes back the aws
      # response directly, but merges in the password that it generated.
      response = rds.create_database("mydb")
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

        fake_response
      end

      rds.create_database("mydb", :allocated_storage => 16, :master_user_password => "swordfish")
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

      db_instance_1.should_receive(:delete).with(skip_final_snapshot: true)
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
