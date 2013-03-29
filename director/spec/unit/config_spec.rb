require 'spec_helper'

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


  context "compiled package cache" do
    context "is configured" do
      before(:each) do
        described_class.configure(test_config)
      end

      it "uses package cache" do
        described_class.use_compiled_package_cache?.should be_true
      end

      it "returns a compiled package cache blobstore" do
        Bosh::Blobstore::Client.should_receive(:create).with('local', 'blobstore_path' => '/path/to/some/bucket')
        described_class.compiled_package_cache_blobstore
      end
    end

    context "is not configured" do
      before(:each) do
        test_config.delete("compiled_package_cache")
        described_class.configure(test_config)
      end

      it "returns false for use_compiled_package_cache?" do
        described_class.use_compiled_package_cache?.should be_false
      end

      it "returns nil for compiled_package_cache" do
        described_class.compiled_package_cache_blobstore.should be_nil
      end
    end
  end
end