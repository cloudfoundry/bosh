require 'spec_helper'
require '20130531180445_create_bosh_rds_db'

describe CreateBoshRdsDb do
  include MigrationSpecHelper

  subject { described_class.new(config, '')}

  before do
    allow(subject).to receive(:load_receipt).and_return(YAML.load_file(asset "test-output.yml"))
  end

  after do
    CreateBoshRdsDb::RdsDb.class_variable_set(:@@receipt, nil)
  end

  it "creates the bosh rds if it does not exist" do
    expect(rds).to receive(:database_exists?).with("bosh").and_return(false)

    create_database_params = ["bosh", ["subnet-xxxxxxx5", "subnet-xxxxxxx6"], "vpc-13724979"]
    expect(rds).to receive(:create_database).with(*create_database_params).and_return(
        :engine => "mysql",
        :master_username => "bosh_user",
        :master_user_password => "bosh_password"
    )

    fake_bosh_rds = double("uaadb",
                         db_name: "uaadb",
                         endpoint_address: '1.2.3.4',
                         endpoint_port: 1234,
                         db_instance_status: :irrelevant)
    fake_uaadb_rds = double("bosh",
                          db_name: "bosh",
                          endpoint_address: '5.6.7.8',
                          endpoint_port: 5678,
                          db_instance_status: :irrelevant)
    expect(rds).to receive(:databases).at_least(:once).and_return([fake_bosh_rds, fake_uaadb_rds])
    expect(rds).to receive(:database).with('bosh').and_return(fake_bosh_rds)

    expect { subject.execute }.to_not raise_error
  end

  it "does not create the bosh rds if it already exists" do
    expect(rds).to receive(:database_exists?).with("bosh").and_return(true)
    expect(Bosh::AwsCliPlugin::MigrationHelper::RdsDb).to receive(:deployment_properties).and_return({})

    create_database_params = ["bosh", ["subnet-xxxxxxx5", "subnet-xxxxxxx6"], "vpc-13724979"]
    expect(rds).not_to receive(:create_database).with(*create_database_params)

    fake_bosh_rds = double("uaadb",
                         db_name: "uaadb",
                         endpoint_address: '1.2.3.4',
                         endpoint_port: 1234,
                         db_instance_status: :irrelevant)
    fake_uaadb_rds = double("bosh",
                          db_name: "bosh",
                          endpoint_address: '5.6.7.8',
                          endpoint_port: 5678,
                          db_instance_status: :irrelevant)
    expect(rds).to receive(:databases).at_least(:once).and_return([fake_bosh_rds, fake_uaadb_rds])

    expect { subject.execute }.to_not raise_error
  end

end
