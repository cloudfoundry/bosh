# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe String do

  it "can tell valid bosh identifiers from invalid" do
    %w(ruby ruby-1.8.7 mysql-2.3.5-alpha Apache_2.3).each do |id|
      id.bosh_valid_id?.should be(true)
    end

    ["ruby 1.8", "ruby-1.8@b29", "#!@", "db/2", "ruby(1.8)"].each do |id|
      id.bosh_valid_id?.should be(false)
    end
  end

  it "can tell blank string from non-blank" do
    [" ", "\t\t", "\n", ""].each do |string|
      string.should be_blank
    end

    ["a", " a", "a ", "  a  ", "___", "z\tb"].each do |string|
      string.should_not be_blank
    end
  end

  it "has colorization helpers (but only if tty)" do
    Bosh::Cli::Config.colorize = false
    "string".make_red.should == "string"
    "string".make_green.should == "string"
    "string".make_color("a").should == "string"
    "string".make_color(:green).should == "string"

    Bosh::Cli::Config.colorize = true
    Bosh::Cli::Config.output.stub(:tty?).and_return(true)
    "string".make_red.should == "\e[0m\e[31mstring\e[0m"
    "string".make_green.should == "\e[0m\e[32mstring\e[0m"
    "string".make_color("a").should == "string"
    "string".make_color(:green).should == "\e[0m\e[32mstring\e[0m"

    Bosh::Cli::Config.output.stub(:tty?).and_return(false)
    "string".make_green.should == "string"
  end

  describe 'columnize' do
    it 'wraps long lines' do
      message = 'hello this is a line that has quite a lot of words'
      formatted_message = "hello this is a line\nthat has quite a lot\nof words"

      line_wrap = double(Bosh::Cli::LineWrap)
      line_wrap.should_receive(:wrap)
        .with(message)
        .and_return(formatted_message)
      Bosh::Cli::LineWrap.should_receive(:new).with(20, 0).and_return(line_wrap)
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
    s.read.should == "yea\nyea\n"

    s.rewind
    header("test")
    s.rewind
    s.read.should == "\ntest\n----\n"

    s.rewind
    header("test", "a")
    s.rewind
    s.read.should == "\ntest\naaaa\n"
  end

  it 'has a warn helper' do
    should_receive(:warn).with("[WARNING] Could not find keypair".make_yellow)

    warning("Could not find keypair")
  end

  it "raises a special exception to signal a premature exit" do
    lambda {
      err("Done")
    }.should raise_error(Bosh::Cli::CliError, "Done")
  end

  it "can tell if object is blank" do
    o = Object.new
    o.stub(:to_s).and_return("  ")
    o.should be_blank
    o.stub(:to_s).and_return("Object 1")
    o.should_not be_blank
  end

  describe "#load_yaml_file" do
    it "can load YAML files with ERB" do
      load_yaml_file(spec_asset("dummy.yml.erb")).should == {"four" => 4}
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
