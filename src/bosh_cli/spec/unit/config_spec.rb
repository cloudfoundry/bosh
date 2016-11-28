# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::Config do
  before :each do
    @config    = File.join(Dir.mktmpdir, "bosh_config")
    @cache_dir = Dir.mktmpdir
  end

  def add_config(object)
    File.open(@config, "w") do |f|
      f.write(Psych.dump(object))
    end
  end

  def create_config
    Bosh::Cli::Config.new(@config)
  end

  describe 'colorize' do
    before do
      Bosh::Cli::Config.colorize = nil
    end

    context 'when colorize is set to false' do
      it 'returns false' do
        Bosh::Cli::Config.colorize = false
        expect(Bosh::Cli::Config.use_color?).to eq(false)
      end
    end

    context 'when colorize is set to true' do
      it 'returns true' do
        Bosh::Cli::Config.colorize = true
        expect(Bosh::Cli::Config.use_color?).to eq(true)
      end
    end

    context 'when output is tty' do
      it 'returns true' do
        Bosh::Cli::Config.output = double(:output, :tty? => true)
        expect(Bosh::Cli::Config.use_color?).to eq(true)
      end
    end

    context 'when output is tty but colorized is forced to false' do
      it 'returns false' do
        Bosh::Cli::Config.colorize = false
        Bosh::Cli::Config.output = double(:output, :tty? => true)
        expect(Bosh::Cli::Config.use_color?).to eq(false)
      end
    end

    context 'when output is not tty' do
      it 'returns false' do
        Bosh::Cli::Config.output = double(:output, :tty? => false)
        expect(Bosh::Cli::Config.use_color?).to eq(false)
      end
    end
  end

  it "should convert old deployment configs to the new config " +
     "when set_deployment is called" do
    add_config("target" => "localhost:8080", "deployment" => "test")

    cfg = create_config
    yaml_file = load_yaml_file(@config, nil)
    expect(yaml_file["deployment"]).to eq("test")
    cfg.set_deployment("test2")
    cfg.save
    yaml_file = load_yaml_file(@config, nil)
    expect(yaml_file["deployment"].has_key?("localhost:8080")).to be(true)
    expect(yaml_file["deployment"]["localhost:8080"]).to eq("test2")
  end

  it "should convert old deployment configs to the new config " +
     "when deployment is called" do
    add_config("target" => "localhost:8080", "deployment" => "test")

    cfg = create_config
    yaml_file = load_yaml_file(@config, nil)
    expect(yaml_file["deployment"]).to eq("test")
    expect(cfg.deployment).to eq("test")
    yaml_file = load_yaml_file(@config, nil)
    expect(yaml_file["deployment"].has_key?("localhost:8080")).to be(true)
    expect(yaml_file["deployment"]["localhost:8080"]).to eq("test")
  end

  it "should save a deployment for each target" do
    add_config({})
    cfg = create_config
    cfg.target = "localhost:1"
    cfg.set_deployment("/path/to/deploy/1")
    cfg.save
    cfg.target = "localhost:2"
    cfg.set_deployment("/path/to/deploy/2")
    cfg.save

    # Test that the file is written correctly.
    yaml_file = load_yaml_file(@config, nil)
    expect(yaml_file["deployment"].has_key?("localhost:1")).to be(true)
    expect(yaml_file["deployment"].has_key?("localhost:2")).to be(true)
    expect(yaml_file["deployment"]["localhost:1"]).to eq("/path/to/deploy/1")
    expect(yaml_file["deployment"]["localhost:2"]).to eq("/path/to/deploy/2")

    # Test that switching targets gives you the new deployment.
    expect(cfg.deployment).to eq("/path/to/deploy/2")
    cfg.target = "localhost:1"
    expect(cfg.deployment).to eq("/path/to/deploy/1")
  end

  it "returns nil when the deployments key exists but has no value" do
    add_config("target" => "localhost:8080", "deployment" => nil)

    cfg = create_config
    yaml_file = load_yaml_file(@config, nil)
    expect(yaml_file["deployment"]).to eq(nil)
    expect(cfg.deployment).to eq(nil)
  end

  it "should throw MissingTarget when getting deployment without target set" do
    add_config({})
    cfg = create_config
    expect { cfg.set_deployment("/path/to/deploy/1") }.
        to raise_error(Bosh::Cli::MissingTarget)
  end

  it "whines on missing config file" do
    expect {
      expect(File).to receive(:open).with(@config, "w").and_raise(Errno::EACCES)
      create_config
    }.to raise_error(Bosh::Cli::ConfigError)
  end


  it "effectively ignores config file if it is malformed" do
    add_config([1, 2, 3])
    cfg = create_config

    expect(cfg.target).to eq(nil)
  end

  it "fetches auth information from the config file" do
    config = {
      "target" => "localhost:8080",
      "deployment" => "test",
      "auth" => {
        "localhost:8080" => { "username" => "a", "password" => "b" },
        "localhost:8081" => { "username" => "c", "password" => "d" }
      }
    }

    add_config(config)
    cfg = create_config

    expect(cfg.username("localhost:8080")).to eq("a")
    expect(cfg.password("localhost:8080")).to eq("b")

    expect(cfg.username("localhost:8081")).to eq("c")
    expect(cfg.password("localhost:8081")).to eq("d")

    expect(cfg.username("localhost:8083")).to be_nil
    expect(cfg.password("localhost:8083")).to be_nil
  end

  describe "max_parallel_downloads" do
    it "is fetched from the config file" do
      config = {
        "max_parallel_downloads" => 3
      }

      add_config(config)
      cfg = create_config

      expect(cfg.max_parallel_downloads).to eq(3)
    end

    it "uses global runtime set if available" do
      cfg = create_config
      Bosh::Cli::Config.max_parallel_downloads = 7
      expect(cfg.max_parallel_downloads).to eq(7)
      Bosh::Cli::Config.max_parallel_downloads = nil
    end

    it "defaults parallel download limit to 1 if none is set" do
      cfg = create_config
      expect(cfg.max_parallel_downloads).to eq(1)
    end
  end
end
