# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe String do

  it "can tell valid bosh identifiers from invalid" do
    %w(ruby ruby-1.8.7 mysql-2.3.5-alpha Apache_2.3).each do |id|
      id.bosh_valid_id?.should be_true
    end

    ["ruby 1.8", "ruby-1.8@b29", "#!@", "db/2", "ruby(1.8)"].each do |id|
      id.bosh_valid_id?.should be_false
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
    "string".red.should   == "string"
    "string".green.should == "string"
    "string".colorize("a").should == "string"
    "string".colorize(:green).should == "string"

    Bosh::Cli::Config.colorize = true
    Bosh::Cli::Config.output.stub(:tty?).and_return(true)
    "string".red.should == "\e[0m\e[31mstring\e[0m"
    "string".green.should == "\e[0m\e[32mstring\e[0m"
    "string".colorize("a").should == "string"
    "string".colorize(:green).should == "\e[0m\e[32mstring\e[0m"

    Bosh::Cli::Config.output.stub(:tty?).and_return(false)
    "string".green.should == "string"
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

  it "raises a special exception to signal a premature exit" do
    lambda {
      err("Done")
    }.should raise_error(Bosh::Cli::CliExit, "Done")
  end

  it "can tell if object is blank" do
    o = Object.new
    o.stub!(:to_s).and_return("  ")
    o.should be_blank
    o.stub!(:to_s).and_return("Object 1")
    o.should_not be_blank
  end

end
