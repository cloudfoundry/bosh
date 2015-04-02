# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe String do

  it "can tell valid bosh identifiers from invalid" do
    %w(ruby ruby-1.8.7 mysql-2.3.5-alpha Apache_2.3).each do |id|
      expect(id.bosh_valid_id?).to be(true)
    end

    ["ruby 1.8", "ruby-1.8@b29", "#!@", "db/2", "ruby(1.8)"].each do |id|
      expect(id.bosh_valid_id?).to be(false)
    end
  end

  it "can tell blank string from non-blank" do
    [" ", "\t\t", "\n", ""].each do |string|
      expect(string).to be_blank
    end

    ["a", " a", "a ", "  a  ", "___", "z\tb"].each do |string|
      expect(string).not_to be_blank
    end
  end

  it "has colorization helpers (but only if tty)" do
    Bosh::Cli::Config.colorize = false
    expect("string".make_red).to eq("string")
    expect("string".make_green).to eq("string")
    expect("string".make_color("a")).to eq("string")
    expect("string".make_color(:green)).to eq("string")

    Bosh::Cli::Config.colorize = true
    allow(Bosh::Cli::Config.output).to receive(:tty?).and_return(true)
    expect("string".make_red).to eq("\e[0m\e[31mstring\e[0m")
    expect("string".make_green).to eq("\e[0m\e[32mstring\e[0m")
    expect("string".make_color("a")).to eq("string")
    expect("string".make_color(:green)).to eq("\e[0m\e[32mstring\e[0m")

    allow(Bosh::Cli::Config.output).to receive(:tty?).and_return(false)

    expect("string".make_green).to eq("\e[0m\e[32mstring\e[0m")

    Bosh::Cli::Config.colorize = nil
    expect("string".make_green).to eq("string")

    Bosh::Cli::Config.colorize = false
    expect("string".make_green).to eq("string")
  end

  describe 'columnize' do
    it 'wraps long lines' do
      message = 'hello this is a line that has quite a lot of words'
      formatted_message = "hello this is a line\nthat has quite a lot\nof words"

      line_wrap = double(Bosh::Cli::LineWrap)
      expect(line_wrap).to receive(:wrap)
        .with(message)
        .and_return(formatted_message)
      expect(Bosh::Cli::LineWrap).to receive(:new).with(20, 0).and_return(line_wrap)
      expect(message.columnize(20)).to eq formatted_message
    end
  end
end

describe Object do

  it "has output helpers" do
    s = StringIO.new
    Bosh::Cli::Config.output = s
    say("yea")
    say("yea")
    s.rewind
    expect(s.read).to eq("yea\nyea\n")

    s.rewind
    header("test")
    s.rewind
    expect(s.read).to eq("\ntest\n----\n")

    s.rewind
    header("test", "a")
    s.rewind
    expect(s.read).to eq("\ntest\naaaa\n")
  end

  it 'has a warn helper' do
    should_receive(:warn).with("[WARNING] Could not find keypair".make_yellow)

    warning("Could not find keypair")
  end

  it "raises a special exception to signal a premature exit" do
    expect {
      err("Done")
    }.to raise_error(Bosh::Cli::CliError, "Done")
  end

  it "can tell if object is blank" do
    o = Object.new
    allow(o).to receive(:to_s).and_return("  ")
    expect(o).to be_blank
    allow(o).to receive(:to_s).and_return("Object 1")
    expect(o).not_to be_blank
  end

  describe "#load_yaml_file" do
    it "can load YAML files with ERB" do
      expect(load_yaml_file(spec_asset("dummy.yml.erb"))).to eq({"four" => 4})
    end

    it "gives a nice error when the file cannot be found" do
      expect {
        load_yaml_file("non-existent.yml")
      }.to raise_error(Bosh::Cli::CliError, "Cannot find file `non-existent.yml'")
    end

    it "gives a nice error when the parsed YAML is not a Hash" do
      expect {
        load_yaml_file(spec_asset("not_a_hash.yml"))
      }.to raise_error(Bosh::Cli::CliError, /Incorrect YAML structure .* expected Hash/)
    end

    it "gives a nice error when the parsed YAML produces a hash with repeated keys" do
      expect {
        load_yaml_file(spec_asset("duplicate_keys.yml"))
      }.to raise_error(Bosh::Cli::CliError, /Incorrect YAML structure .* duplicate key 'unique_key'/)
    end
  end
end
