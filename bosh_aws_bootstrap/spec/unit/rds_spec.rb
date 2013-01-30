require 'spec_helper'

describe Bosh::Aws::RDS do
  let(:rds) { described_class.new({}) }
  let(:db_instance_1) { double("database instance", name: 'bosh_db', id: "db1") }
  let(:db_instance_2) { double("database instance", name: 'cc_db', id: "db2") }

  before(:each) do
    fake_aws_rds = double("aws_rds", db_instances: [db_instance_1, db_instance_2])

    rds.stub(:aws_rds).and_return(fake_aws_rds)
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
