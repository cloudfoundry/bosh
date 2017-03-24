require "spec_helper"

describe Bosh::Registry do

  describe "configuring registry" do

    it "validates configuration file" do
      expect {
        Bosh::Registry.configure("foobar")
      }.to raise_error(Bosh::Registry::ConfigError, /Invalid config format/)

      config = valid_config.merge("http" => nil)

      expect {
        Bosh::Registry.configure(config)
      }.to raise_error(Bosh::Registry::ConfigError, /HTTP configuration is missing/)

      config = valid_config.merge("db" => nil)

      expect {
        Bosh::Registry.configure(config)
      }.to raise_error(Bosh::Registry::ConfigError, /Database configuration is missing/)

      config = valid_config
      config.delete("cloud")

      expect {
        Bosh::Registry.configure(config)
      }.to_not raise_error

      config = valid_config.merge("cloud" => nil)

      expect {
        Bosh::Registry.configure(config)
      }.to raise_error(Bosh::Registry::ConfigError, /Cloud configuration is missing/)

      config = valid_config
      config["cloud"]["plugin"] = nil

      expect {
        Bosh::Registry.configure(config)
      }.to raise_error(Bosh::Registry::ConfigError, /Cloud plugin is missing/)

      config = valid_config

      expect {
        Bosh::Registry.configure(config)
      }.to raise_error(Bosh::Registry::ConfigError, /Could not find Provider Plugin/)
    end

    it "reads provided configuration file and sets singletons for AWS" do
      config = valid_config
      config["cloud"] = {
        "plugin" => "aws",
        "aws" => {
          "access_key_id" => "foo",
          "secret_access_key" => "bar",
          "region" => "foobar",
          "max_retries" => 5
        }
      }
      Bosh::Registry.configure(config)

      logger = Bosh::Registry.logger

      expect(logger).to be_kind_of(Logger)
      expect(logger.level).to eq(Logger::DEBUG)

      expect(Bosh::Registry.http_port).to eq(25777)
      expect(Bosh::Registry.http_user).to eq("admin")
      expect(Bosh::Registry.http_password).to eq("admin")

      db = Bosh::Registry.db
      expect(db).to be_kind_of(Sequel::SQLite::Database)
      expect(db.opts[:database]).to eq("/:memory:")
      expect(db.opts[:max_connections]).to eq(433)
      expect(db.opts[:pool_timeout]).to eq(227)

      im = Bosh::Registry.instance_manager
      expect(im).to be_kind_of(Bosh::Registry::InstanceManager::Aws)
    end

    it "reads provided configuration file and sets singletons for OpenStack" do
      allow(Fog::Compute).to receive(:new)

      config = valid_config
      config["cloud"] = {
        "plugin" => "openstack",
        "openstack" => {
          "auth_url" => "http://127.0.0.1:5000/v2.0",
          "username" => "foo",
          "api_key" => "bar",
          "tenant" => "foo",
          "region" => ""
        }
      }
      Bosh::Registry.configure(config)

      logger = Bosh::Registry.logger

      expect(logger).to be_kind_of(Logger)
      expect(logger.level).to eq(Logger::DEBUG)

      expect(Bosh::Registry.http_port).to eq(25777)
      expect(Bosh::Registry.http_user).to eq("admin")
      expect(Bosh::Registry.http_password).to eq("admin")

      db = Bosh::Registry.db
      expect(db).to be_kind_of(Sequel::SQLite::Database)
      expect(db.opts[:database]).to eq("/:memory:")
      expect(db.opts[:max_connections]).to eq(433)
      expect(db.opts[:pool_timeout]).to eq(227)

      im = Bosh::Registry.instance_manager
      expect(im).to be_kind_of(Bosh::Registry::InstanceManager::Openstack)
    end

    it "reads provided configuration file and sets singletons for Azure" do
      allow(Fog::Compute).to receive(:new)

      config = valid_config
      config.delete("cloud")
      Bosh::Registry.configure(config)

      logger = Bosh::Registry.logger

      expect(logger).to be_kind_of(Logger)
      expect(logger.level).to eq(Logger::DEBUG)

      expect(Bosh::Registry.http_port).to eq(25777)
      expect(Bosh::Registry.http_user).to eq("admin")
      expect(Bosh::Registry.http_password).to eq("admin")

      db = Bosh::Registry.db
      expect(db).to be_kind_of(Sequel::SQLite::Database)
      expect(db.opts[:database]).to eq("/:memory:")
      expect(db.opts[:max_connections]).to eq(433)
      expect(db.opts[:pool_timeout]).to eq(227)

      im = Bosh::Registry.instance_manager
      expect(im).to be_kind_of(Bosh::Registry::InstanceManager)
    end

  end

  describe "database configuration" do

    let(:database_options) do
      {
          'adapter' => 'sqlite',
          'connection_options' => {
              'max_connections' => 32
          }

      }
    end
    let(:database_connection) { double('Database Connection').as_null_object }

    before do
      allow(Sequel).to receive(:connect).and_return(database_connection)
    end

    it "configures a new database connection" do
      expect(described_class.connect_db(database_options)).to eq database_connection
    end

    it "merges connection options together with the rest of the database options" do
      expected_options = {
          'adapter' => 'sqlite',
          'max_connections' => 32
      }
      expect(Sequel).to receive(:connect).with(expected_options).and_return(database_connection)
      described_class.connect_db(database_options)
    end

    it "ignores empty and nil options" do
      expect(Sequel).to receive(:connect).with('baz' => 'baz').and_return(database_connection)
      described_class.connect_db('foo' => nil, 'bar' => '', 'baz' => 'baz')
    end

    context "when logger is available" do
      before do
        allow(described_class).to receive(:logger).and_return(double('Fake Logger'))
      end

      it "sets the database logger" do
        expect(database_connection).to receive(:logger=)
        expect(database_connection).to receive(:sql_log_level=)
        described_class.connect_db(database_options)
      end
    end

    context "when logger is unavailable" do
      before do
        allow(described_class).to receive(:logger).and_return(nil)
      end

      it "does not sets the database logger" do
        expect(database_connection).not_to receive(:logger=)
        expect(database_connection).not_to receive(:sql_log_level=)
        described_class.connect_db(database_options)
      end
    end
  end

end