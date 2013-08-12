require 'spec_helper'
require '20130412183544_create_rds_dbs'

describe CreateRdsDbs do
  include MigrationSpecHelper

  subject { described_class.new(config, nil, '') }

  before do
    subject.stub(:load_receipt).and_return(YAML.load_file(asset "test-output.yml"))
    Kernel.stub(:sleep)
  end

  def make_rds!(opts = {})
    retries_needed = opts[:retries_needed] || 0
    creation_options = opts[:aws_creation_options]

    rds.should_receive(:database_exists?).with("ccdb").and_return(false)

    create_database_params = ["ccdb", ["subnet-xxxxxxx3", "subnet-xxxxxxx4"], "vpc-13724979"]
    create_database_params << creation_options if creation_options
    rds.should_receive(:create_database).with(*create_database_params).and_return(
        :engine => "mysql",
        :master_username => "ccdb_user",
        :master_user_password => "ccdb_password"
    )

    rds.should_receive(:database_exists?).with("uaadb").and_return(false)
    rds.should_receive(:create_database).
        with("uaadb", ["subnet-xxxxxxx3", "subnet-xxxxxxx4"], "vpc-13724979").and_return(
        :engine => "mysql",
        :master_username => "uaa_user",
        :master_user_password => "uaa_password")

    fake_ccdb_rds = double("ccdb", db_name: "ccdb", endpoint_port: 1234, db_instance_status: :irrelevant)
    fake_uaadb_rds = double("uaadb", db_name: "uaadb", endpoint_port: 5678, db_instance_status: :irrelevant)
    rds.should_receive(:databases).at_least(:once).and_return([fake_ccdb_rds, fake_uaadb_rds])

    ccdb_endpoint_address_response = ([nil] * retries_needed) << "1.2.3.4"
    fake_ccdb_rds.stub(:endpoint_address).and_return(*ccdb_endpoint_address_response)

    uaadb_endpoint_address_response = ([nil] * retries_needed) << "5.6.7.8"
    fake_uaadb_rds.stub(:endpoint_address).and_return(*uaadb_endpoint_address_response)

    rds.stub(:database).with("ccdb").and_return(fake_ccdb_rds)
    rds.stub(:database).with("uaadb").and_return(fake_uaadb_rds)

    rds
  end

  it "should create all rds databases" do
    make_rds!
    subject.execute
  end

  context "when the config file has option overrides" do
    let(:config_file) { asset "config_with_override.yml" }

    it "should create all rds databases with option overrides" do
      ccdb_opts = Psych.load_file(config_file)["rds"].find { |db_opts| db_opts["instance"] == "ccdb" }
      make_rds!(aws_creation_options: ccdb_opts["aws_creation_options"])
      subject.execute
    end
  end

  it "should flush the output to a YAML file" do
    make_rds!


    subject.should_receive(:save_receipt) do |receipt_name, receipt|
      receipt_name.should == 'aws_rds_receipt'
      deployment_manifest_properties = receipt["deployment_manifest"]["properties"]

      deployment_manifest_properties["ccdb"].should == {
          "db_scheme" => "mysql",
          "address" => "1.2.3.4",
          "port" => 1234,
          "roles" => [
              {
                  "tag" => "admin",
                  "name" => "ccdb_user",
                  "password" => "ccdb_password"
              }
          ],
          "databases" => [
              {
                  "tag" => "cc",
                  "name" => "ccdb"
              }
          ]
      }

      deployment_manifest_properties["uaadb"].should == {
          "db_scheme" => "mysql",
          "address" => "5.6.7.8",
          "port" => 5678,
          "roles" => [
              {
                  "tag" => "admin",
                  "name" => "uaa_user",
                  "password" => "uaa_password"
              }
          ],
          "databases" => [
              {
                  "tag" => "uaa",
                  "name" => "uaadb"
              }
          ]
      }
    end

    subject.execute
  end

  context "when the RDS is not immediately available" do

    it "should try several times and continue when available" do
      make_rds!(retries_needed: 3)
      expect { subject.execute }.to_not raise_error
    end

    it "should fail after 540 attempts when not available" do
      make_rds!(retries_needed: 541)
      expect { subject.execute }.to raise_error
    end
  end
end
