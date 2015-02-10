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

      expect(described_class.max_tasks).to eq(10)
    end

    it "sets a default" do
      described_class.configure(test_config)

      expect(described_class.max_tasks).to eq(500)
    end
  end

  context "max_threads" do
    it "can set max_threads in config" do
      test_config["max_threads"] = 10
      described_class.configure(test_config)

      expect(described_class.max_threads).to eq(10)
    end

    it "sets a default" do
      described_class.configure(test_config)

      expect(described_class.max_threads).to eq(32)
    end
  end

  context "automatically fix stateful nodes" do
    it "can set fixing stateful nodes in config" do
      test_config["scan_and_fix"]["auto_fix_stateful_nodes"] = true
      described_class.configure(test_config)

      expect(described_class.fix_stateful_nodes).to eq(true)
    end

    it "sets a default" do
      test_config["scan_and_fix"].delete("auto_fix_stateful_nodes")

      described_class.configure(test_config)
      expect(described_class.fix_stateful_nodes).to eq(false)

      test_config.delete("scan_and_fix")
      described_class.configure(test_config)
      expect(described_class.fix_stateful_nodes).to eq(false)
    end
  end

  context "enable_snapshots" do
    it "can enable snapshots in config" do
      test_config["snapshots"]["enabled"] = true
      described_class.configure(test_config)

      expect(described_class.enable_snapshots).to eq(true)
    end

    it "sets a default" do
      described_class.configure(test_config)

      expect(described_class.enable_snapshots).to eq(false)
    end
  end

  context "compiled package cache" do
    context "is configured" do
      before(:each) do
        described_class.configure(test_config)
      end

      it "uses package cache" do
        expect(described_class.use_compiled_package_cache?).to be(true)
      end

      it "returns a compiled package cache blobstore" do
        expect(Bosh::Blobstore::Client)
          .to receive(:safe_create)
          .with('local', 'blobstore_path' => '/path/to/some/bucket')
        described_class.compiled_package_cache_blobstore
      end
    end

    context "is not configured" do
      before { test_config.delete("compiled_package_cache") }

      it "returns false for use_compiled_package_cache?" do
        described_class.configure(test_config)
        expect(described_class.use_compiled_package_cache?).to be(false)
      end

      it "returns nil for compiled_package_cache" do
        described_class.configure(test_config)
        expect(described_class.compiled_package_cache_blobstore).to be_nil
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
      allow(Sequel).to receive(:connect).and_return(database_connection)
    end

    it "configures a new database connection" do
      expect(described_class.configure_db(database_options)).to eq database_connection
    end

    it "patches sequel for the sqlite adapter" do
      expect(described_class).to receive(:patch_sqlite)
      described_class.configure_db(database_options)

      expect(described_class).not_to receive(:patch_sqlite)
      described_class.configure_db(database_options.merge('adapter' => 'postgres'))
    end

    it "merges connection options together with the rest of the database options" do
      expected_options = {
          'adapter' => 'sqlite',
          'max_connections' => 32
      }
      expect(Sequel).to receive(:connect).with(expected_options).and_return(database_connection)
      described_class.configure_db(database_options)
    end

    it "ignores empty and nil options" do
      expect(Sequel).to receive(:connect).with('baz' => 'baz').and_return(database_connection)
      described_class.configure_db('foo' => nil, 'bar' => '', 'baz' => 'baz')
    end

    context "when logger is available" do
      it "sets the database logger" do
        expect(database_connection).to receive(:logger=)
        expect(database_connection).to receive(:sql_log_level=)
        described_class.configure_db(database_options)
      end
    end

    context "when logger is unavailable" do
      before do
        allow(described_class).to receive(:logger).and_return(nil)
      end

      it "does not sets the database logger" do
        expect(database_connection).not_to receive(:logger=)
        expect(database_connection).not_to receive(:sql_log_level=)
        described_class.configure_db(database_options)
      end
    end

    describe '.override_uuid' do
      context 'when the state.json file exists' do
        before { open(state_json, 'w') { |f| f.write("{\"uuid\":\"testuuid\"}") } }
        let(:state_json) { File.join(test_config['dir'], 'state.json') }

        it 'inserts the uuid from state.json into the database' do
          described_class.configure(test_config)
          uuid = Bosh::Director::Models::DirectorAttribute.first(name: 'uuid')
          expect(uuid.value).to eq('testuuid')
        end

        it 'deletes state.json' do
          described_class.configure(test_config)
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
