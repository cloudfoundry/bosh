require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Agent::Template do

  it "should create a template" do
    dummy = "hubba"
    dst = File.join(base_dir, 'yabba.out')

    Bosh::Agent::Template.write do |t|
      t.src("platform/dummy/templates/dummy_template.erb")
      t.dst(dst)
    end

    File.read(dst).should == "This is a dummy variable with hubba value\n"
  end

  it "should fail when variable is not in binding scope" do
    dst = File.join(base_dir, 'yabba.out')

    lambda {
      Bosh::Agent::Template.write do |t|
        t.src("platform/dummy/templates/dummy_template.erb")
        t.dst(dst)
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
    block = lambda { |t| t.src("platform/dummy/templates/dummy_template.erb") }
    template = Bosh::Agent::Template.new(block)
    template.render.should == "This is a dummy variable with bubba value\n"
  end

  it "should require a source template" do
    lambda {
      Bosh::Agent::Template.write { |t| t.class }
    }.should raise_error(Bosh::Agent::Template::TemplateDataError)
  end

end
