# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::Api::PropertyManager do
  def make_deployment
    BD::Models::Deployment.make(:name => "mycloud")
  end

  before :each do
    @manager = BDA::PropertyManager.new
  end

  it "creates/reads properties" do
    make_deployment
    @manager.create_property("mycloud", "foo", "bar")
    @manager.get_property("mycloud", "foo").value.should == "bar"
  end

  it "doesn't allow duplicate property names" do
    make_deployment
    @manager.create_property("mycloud", "foo", "bar")

    lambda {
      @manager.create_property("mycloud", "foo", "baz")
    }.should raise_error(BD::PropertyAlreadyExists,
                         "Property `foo' already exists " +
                         "for deployment `mycloud'")
  end

  it "doesn't allow invalid properties" do
    lambda {
      @manager.create_property("mycloud", "foo", "bar")
    }.should raise_error(BD::DeploymentNotFound,
                         "Deployment `mycloud' doesn't exist")

    make_deployment

    lambda {
      @manager.create_property("mycloud", "foo$", "bar")
    }.should raise_error(BD::PropertyInvalid,
                         "Property is invalid: name format")

    lambda {
      @manager.create_property("mycloud", "", "bar")
    }.should raise_error(BD::PropertyInvalid,
                         "Property is invalid: name presence")

    lambda {
      @manager.create_property("mycloud", "foo", "")
    }.should raise_error(BD::PropertyInvalid,
                         "Property is invalid: value presence")

    lambda {
      @manager.create_property("mycloud", "foo$", "")
    }.should raise_error(BD::PropertyInvalid,
                         "Property is invalid: name format, value presence")
  end

  it "updates properties" do
    make_deployment

    @manager.create_property("mycloud", "foo", "bar")
    @manager.update_property("mycloud", "foo", "baz")
    @manager.get_property("mycloud", "foo").value.should == "baz"
  end

  it "doesn't allow invalid updates" do
    lambda {
      @manager.update_property("mycloud", "foo", "bar")
    }.should raise_error(BD::DeploymentNotFound,
                         "Deployment `mycloud' doesn't exist")

    make_deployment

    lambda {
      @manager.update_property("mycloud", "foo", "baz")
    }.should raise_error(BD::PropertyNotFound,
        "Property `foo' not found for deployment `mycloud'")

    @manager.create_property("mycloud", "foo", "bar")

    lambda {
      @manager.update_property("mycloud", "foo", "")
    }.should raise_error(BD::PropertyInvalid,
                         "Property is invalid: value presence")
  end

  it "allows deleting properties" do
    make_deployment

    @manager.create_property("mycloud", "foo", "bar")
    @manager.delete_property("mycloud", "foo")
    lambda {
      @manager.get_property("mycloud", "foo")
    }.should raise_error(BD::PropertyNotFound)
  end

  it "doesn't allow invalid deletes" do
    lambda {
      @manager.delete_property("mycloud", "foo")
    }.should raise_error(BD::DeploymentNotFound,
                         "Deployment `mycloud' doesn't exist")

    make_deployment

    lambda {
      @manager.delete_property("mycloud", "foo")
    }.should raise_error(BD::PropertyNotFound,
        "Property `foo' not found for deployment `mycloud'")
  end

  it "lists all properties" do
    make_deployment

    @manager.get_properties("mycloud").should == []

    @manager.create_property("mycloud", "foo", "bar")
    @manager.create_property("mycloud", "password", "secret")

    properties = @manager.get_properties("mycloud")
    properties.size.should == 2

    [properties[0].value, properties[1].value].sort.should == %W(bar secret)
  end

end
