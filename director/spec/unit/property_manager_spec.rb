require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::PropertyManager do

  def manager(scope, name)
    manager = Bosh::Director::PropertyManager.new

    case scope.to_s
    when "deployment"
      manager.scope = Bosh::Director::DeploymentPropertyScope.new(name)
    when "release"
      manager.scope = Bosh::Director::ReleasePropertyScope.new(name)
    end

    manager
  end

  def make_deployment
    Bosh::Director::Models::Deployment.make(:name => "mycloud")
  end

  def make_release
    Bosh::Director::Models::Release.make(:name => "appcloud")
  end

  before :each do
    @dp_manager = manager("deployment", "mycloud")
    @rp_manager = manager("release", "appcloud")
  end

  it "creates/reads properties" do
    make_deployment
    make_release

    @dp_manager.create_property("foo", "bar")
    @rp_manager.create_property("bar", "baz")

    @dp_manager.get_property("foo").value.should == "bar"
    @rp_manager.get_property("bar").value.should == "baz"
  end

  it "doesn't allow duplicate property names" do
    make_deployment
    make_release

    @dp_manager.create_property("foo", "bar")
    @rp_manager.create_property("foo", "bar")

    lambda {
      @dp_manager.create_property("foo", "baz")
    }.should raise_error(Bosh::Director::PropertyAlreadyExists, 'Property "foo" already exists for deployment "mycloud"')

    lambda {
      @rp_manager.create_property("foo", "baz")
    }.should raise_error(Bosh::Director::PropertyAlreadyExists, 'Property "foo" already exists for release "appcloud"')
  end

  it "doesn't allow invalid properties" do
    lambda {
      @dp_manager.create_property("foo", "bar")
    }.should raise_error(Bosh::Director::DeploymentNotFound, 'Deployment "mycloud" doesn\'t exist')

    lambda {
      @rp_manager.create_property("foo", "bar")
    }.should raise_error(Bosh::Director::ReleaseNotFound, 'Release "appcloud" doesn\'t exist')

    make_deployment
    make_release

    [ @dp_manager, @rp_manager ].each do |manager|
      lambda {
        manager.create_property("foo$", "bar")
      }.should raise_error(Bosh::Director::PropertyInvalid, 'Property is invalid: name format')

      lambda {
        manager.create_property("", "bar")
      }.should raise_error(Bosh::Director::PropertyInvalid, 'Property is invalid: name presence')

      lambda {
        manager.create_property("foo", "")
      }.should raise_error(Bosh::Director::PropertyInvalid, 'Property is invalid: value presence')

      lambda {
        manager.create_property("foo$", "")
      }.should raise_error(Bosh::Director::PropertyInvalid, 'Property is invalid: name format, value presence')
    end
  end

  it "updates properties" do
    make_deployment
    make_release

    [ @dp_manager, @rp_manager ].each do |manager|
      manager.create_property("foo", "bar")
      manager.update_property("foo", "baz")
      manager.get_property("foo").value.should == "baz"
    end
  end

  it "doesn't allow invalid updates" do
    lambda {
      @dp_manager.update_property("foo", "bar")
    }.should raise_error(Bosh::Director::DeploymentNotFound, 'Deployment "mycloud" doesn\'t exist')

    lambda {
      @rp_manager.update_property("foo", "bar")
    }.should raise_error(Bosh::Director::ReleaseNotFound, 'Release "appcloud" doesn\'t exist')

    make_deployment
    make_release

    lambda {
      @dp_manager.update_property("foo", "baz")
    }.should raise_error(Bosh::Director::PropertyNotFound, 'Property "foo" not found for deployment "mycloud"')

    lambda {
      @rp_manager.update_property("foo", "baz")
    }.should raise_error(Bosh::Director::PropertyNotFound, 'Property "foo" not found for release "appcloud"')

    [ @dp_manager, @rp_manager ].each do |manager|
      lambda {
        manager.create_property("foo", "bar")
        manager.update_property("foo", "")
      }.should raise_error(Bosh::Director::PropertyInvalid, 'Property is invalid: value presence')
    end
  end

  it "allows deleting properties" do
    make_deployment
    make_release

    [ @dp_manager, @rp_manager ].each do |manager|
      manager.create_property("foo", "bar")
      manager.delete_property("foo")
      lambda { manager.get_property("foo") }.should raise_error(Bosh::Director::PropertyNotFound)
    end
  end

  it "doesn't allow invalid deletes" do
    lambda {
      @dp_manager.delete_property("foo")
    }.should raise_error(Bosh::Director::DeploymentNotFound, 'Deployment "mycloud" doesn\'t exist')

    lambda {
      @rp_manager.delete_property("foo")
    }.should raise_error(Bosh::Director::ReleaseNotFound, 'Release "appcloud" doesn\'t exist')

    make_deployment
    make_release

    lambda {
      @dp_manager.delete_property("foo")
    }.should raise_error(Bosh::Director::PropertyNotFound, 'Property "foo" not found for deployment "mycloud"')

    lambda {
      @rp_manager.delete_property("foo")
    }.should raise_error(Bosh::Director::PropertyNotFound, 'Property "foo" not found for release "appcloud"')
  end

  it "lists all properties" do
    make_deployment
    make_release

    [ @dp_manager, @rp_manager ].each do |manager|
      manager.get_properties.should == []

      manager.create_property("foo", "bar")
      manager.create_property("password", "secret")

      properties = manager.get_properties
      properties.size.should == 2

      [ properties[0].value, properties[1].value ].sort.should == ["bar", "secret"]
    end
  end

end
