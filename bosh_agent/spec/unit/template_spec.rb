# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

describe Bosh::Agent::Template do

  before(:each) do
    @tmp_dir = Dir.mktmpdir
    @src = File.join(@tmp_dir, "dummy_template.erb")
    File.open(@src, "w") { |f|
      f.write("This is a dummy variable with <%= dummy %> value\n")
    }
    @dst = File.join(@tmp_dir, "yabba.out")
  end

  after(:each) do
    FileUtils.rm_rf @tmp_dir
  end

  it "should create a template" do
    dummy = "hubba"

    Bosh::Agent::Template.write do |t|
      t.src @src
      t.dst @dst
    end

    File.read(@dst).should == "This is a dummy variable with hubba value\n"
  end

  it "should fail when variable is not in binding scope" do
    lambda {
      Bosh::Agent::Template.write do |t|
        t.src @src
        t.dst @dst
      end
    }.should raise_error(NameError)
  end

  it "should require a block with arity 1" do
    good_block = lambda { |t| t.src(StringIO.new("foo")) }
    Bosh::Agent::Template.new(good_block)

    bad_block = lambda { false }
    lambda {
      Bosh::Agent::Template.new(bad_block)
    }.should raise_error(ArgumentError)

    lambda {
      Bosh::Agent::Template.new
    }.should raise_error(ArgumentError)
  end

  it "should take a block" do
    dummy = "bubba"
    block = lambda { |t| t.src(@src) }
    template = Bosh::Agent::Template.new(block)
    template.render.should == "This is a dummy variable with bubba value\n"
  end

  it "should require a source template" do
    lambda {
      Bosh::Agent::Template.write { |t| t.class }
    }.should raise_error(Bosh::Agent::Template::TemplateDataError)
  end

end
