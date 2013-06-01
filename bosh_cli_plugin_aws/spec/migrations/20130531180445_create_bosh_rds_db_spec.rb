require 'spec_helper'
require '20130531180445_create_bosh_rds_db'

describe CreateBoshRdsDb do
  include MigrationSpecHelper

  subject { described_class.new(config, '')}

  before do
    subject.stub(:load_receipt).and_return(YAML.load_file(asset "test-output.yml"))
  end

  it "creates the bosh rds if it does not exist" do
    rds.should_receive(:database_exists?).with("bosh").and_return(false)

    create_database_params = ["bosh", ["subnet-xxxxxxx5", "subnet-xxxxxxx6"], "vpc-13724979"]
    rds.should_receive(:create_database).with(*create_database_params)

    expect { subject.execute }.to_not raise_error
  end

  it "does not create the bosh rds if it already exists" do

  end

end
