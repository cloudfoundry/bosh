# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::AwsRegistry::Runner do

  def make_runner(config_file)
    Bosh::AwsRegistry::Runner.new(config_file)
  end

  def write_config(file, config)
    File.open(file, "w") do |f|
      YAML.dump(config, f)
    end
  end

  describe "initializing" do
    it "configures AWS registry using provided file" do
      config_file = Tempfile.new("config")
      config = { "key" => "value" }
      write_config(config_file.path, config)

      Bosh::AwsRegistry.should_receive(:configure).with(config)
      make_runner(config_file.path)
    end

    it "fails if config file not found" do
      expect {
        make_runner("foo")
      }.to raise_error(Bosh::AwsRegistry::ConfigError, "Cannot find file `foo'")
    end

    it "fails when config file has incorrect format" do
      config_file = Tempfile.new("config")
      config = "foo"
      write_config(config_file.path, config)

      expect {
        make_runner(config_file.path)
      }.to raise_error(Bosh::AwsRegistry::ConfigError, /Incorrect file format/)
    end

    it "fails when some syscall fails" do
      config_file = Tempfile.new("config")
      write_config(config_file.path, { "foo" => "bar" })

      YAML.stub!(:load_file).and_raise(SystemCallError.new("baz"))

      expect {
        make_runner(config_file.path)
      }.to raise_error(Bosh::AwsRegistry::ConfigError, /baz/)
    end
  end

  describe "running/stopping" do
    before(:each) do
      @config_file = Tempfile.new("config")
      write_config(@config_file.path, valid_config)
    end

    it "spins up/shuts down reactor and HTTP server" do
      runner = make_runner(@config_file)
      mock_thin = mock("thin")

      EM.should_receive(:run).and_yield

      Thin::Server.should_receive(:new).
        with("0.0.0.0", 25777, :signals => false).
        and_return(mock_thin)

      mock_thin.should_receive(:start!)

      runner.run

      mock_thin.should_receive(:stop!)
      EM.should_receive(:stop)

      runner.stop
    end
  end

end


