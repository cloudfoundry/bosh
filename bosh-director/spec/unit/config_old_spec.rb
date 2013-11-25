require 'spec_helper'

#
# This tests the old class-method behavior of Config. We are
# replacing it with instance behavior tested in the config_spec.rb
#

describe Bosh::Director::Config do
  let(:test_config) { Psych.load(spec_asset("test-director-config.yml")) }

  context "max_tasks" do
    it "can set max_tasks in config" do
      test_config["max_tasks"] = 10
      described_class.configure(test_config)

      described_class.max_tasks.should == 10
    end

    it "sets a default" do
      described_class.configure(test_config)

      described_class.max_tasks.should == 500
    end
  end

  context "max_threads" do
    it "can set max_threads in config" do
      test_config["max_threads"] = 10
      described_class.configure(test_config)

      described_class.max_threads.should == 10
    end

    it "sets a default" do
      described_class.configure(test_config)

      described_class.max_threads.should == 32
    end
  end

  context "automatically fix stateful nodes" do
    it "can set fixing stateful nodes in config" do
      test_config["scan_and_fix"]["auto_fix_stateful_nodes"] = true
      described_class.configure(test_config)

      described_class.fix_stateful_nodes.should == true
    end

    it "sets a default" do
      test_config["scan_and_fix"].delete("auto_fix_stateful_nodes")

      described_class.configure(test_config)
      described_class.fix_stateful_nodes.should == false

      test_config.delete("scan_and_fix")
      described_class.configure(test_config)
      described_class.fix_stateful_nodes.should == false
    end
  end

  context "enable_snapshots" do
    it "can enable snapshots in config" do
      test_config["snapshots"]["enabled"] = true
      described_class.configure(test_config)

      described_class.enable_snapshots.should == true
    end

    it "sets a default" do
      described_class.configure(test_config)

      described_class.enable_snapshots.should == false
    end
  end

  context "compiled package cache" do
    context "is configured" do
      before(:each) do
        described_class.configure(test_config)
      end

      it "uses package cache" do
        described_class.use_compiled_package_cache?.should be(true)
      end

      it "returns a compiled package cache blobstore" do
        Bosh::Blobstore::Client
          .should_receive(:safe_create)
          .with('local', 'blobstore_path' => '/path/to/some/bucket')
        described_class.compiled_package_cache_blobstore
      end
    end

    context "is not configured" do
      before { test_config.delete("compiled_package_cache") }

      it "returns false for use_compiled_package_cache?" do
        described_class.configure(test_config)
        described_class.use_compiled_package_cache?.should be(false)
      end

      it "returns nil for compiled_package_cache" do
        described_class.configure(test_config)
        described_class.compiled_package_cache_blobstore.should be_nil
      end
    end
  end

  context "database" do
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
      Sequel.stub(:connect).and_return(database_connection)
    end

    it "configures a new database connection" do
      expect(described_class.configure_db(database_options)).to eq database_connection
    end

    it "patches sequel for the sqlite adapter" do
      described_class.should_receive(:patch_sqlite)
      described_class.configure_db(database_options)

      described_class.should_not_receive(:patch_sqlite)
      described_class.configure_db(database_options.merge('adapter' => 'postgres'))
    end

    it "merges connection options together with the rest of the database options" do
      expected_options = {
          'adapter' => 'sqlite',
          'max_connections' => 32
      }
      Sequel.should_receive(:connect).with(expected_options).and_return(database_connection)
      described_class.configure_db(database_options)
    end

    it "ignores empty and nil options" do
      Sequel.should_receive(:connect).with('baz' => 'baz').and_return(database_connection)
      described_class.configure_db('foo' => nil, 'bar' => '', 'baz' => 'baz')
    end

    context "when logger is available" do
      before do
        described_class.stub(:logger).and_return(double('Fake Logger'))
      end

      it "sets the database logger" do
        database_connection.should_receive(:logger=)
        database_connection.should_receive(:sql_log_level=)
        described_class.configure_db(database_options)
      end
    end

    context "when logger is unavailable" do
      before do
        described_class.stub(:logger).and_return(nil)
      end

      it "does not sets the database logger" do
        database_connection.should_not_receive(:logger=)
        database_connection.should_not_receive(:sql_log_level=)
        described_class.configure_db(database_options)
      end
    end

    context 'retrieve_uuid' do

      context 'when the uuid is not stored' do

        it 'creates and stores a new uuid' do
          expect { described_class.configure(test_config) }.to change {
            Bosh::Director::Models::DirectorAttribute.all.size }.from(0).to(1)
        end
      end

      context 'when the uuid is already stored' do
        let(:uuid) { 'testuuid' }

        before(:each) do
          Bosh::Director::Models::DirectorAttribute.create(uuid: uuid)
        end

        it 'retrieves the existing uuid' do
          expect { described_class.configure(test_config) }.to_not change { Bosh::Director::Models::DirectorAttribute.all.size }

          expect(described_class.uuid).to eq uuid
        end

      end

    end

    context 'override_uuid' do
      let(:uuid) { 'testuuid' }
      let(:state_json) { File.join(test_config['dir'], 'state.json') }

      context 'when the state.json file exists' do

        before(:each) do
          open(state_json, 'w') do |f|
            f.write("{\"uuid\":\"#{uuid}\"}")
          end

          described_class.configure(test_config)
        end

        it 'inserts the uuid from state.json into the database' do
          attrs = Bosh::Director::Models::DirectorAttribute.all
          expect(attrs.size).to eq 1
          expect(attrs.first.uuid).to eq uuid
        end

        it 'deletes state.json' do
          expect(File.exist?(state_json)).to be(false)
        end
      end

      context 'when the state.json file does not exist' do

        it 'returns nil' do
          described_class.configure(test_config)
          expect(described_class.override_uuid).to be_nil
        end

      end

    end

    context 'database backup' do
      it 'configured a database backup adapter' do
        described_class.configure_db(database_options)
        expect(described_class.configure_db(database_options)).to eq database_connection
      end
    end

  end
end
