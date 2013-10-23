# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

module Bosh::Director
  describe Api::PropertyManager do
    subject(:property_manager) { Api::PropertyManager.new }

    def make_deployment
      Models::Deployment.make(name: 'mycloud')
    end

    it 'creates/reads properties' do
      make_deployment
      property_manager.create_property('mycloud', 'foo', 'bar')
      property_manager.get_property('mycloud', 'foo').value.should == 'bar'
    end

    it "doesn't allow duplicate property names" do
      make_deployment
      property_manager.create_property('mycloud', 'foo', 'bar')

      lambda {
        property_manager.create_property('mycloud', 'foo', 'baz')
      }.should raise_error(PropertyAlreadyExists, "Property `foo' already exists for deployment `mycloud'")
    end

    it "doesn't allow invalid properties" do
      lambda {
        property_manager.create_property('mycloud', 'foo', 'bar')
      }.should raise_error(DeploymentNotFound, "Deployment `mycloud' doesn't exist")

      make_deployment

      lambda {
        property_manager.create_property('mycloud', 'foo$', 'bar')
      }.should raise_error(PropertyInvalid, 'Property is invalid: name format')

      lambda {
        property_manager.create_property('mycloud', '', 'bar')
      }.should raise_error(PropertyInvalid, 'Property is invalid: name presence')

      lambda {
        property_manager.create_property('mycloud', 'foo', '')
      }.should raise_error(PropertyInvalid, 'Property is invalid: value presence')

      lambda {
        property_manager.create_property('mycloud', 'foo$', '')
      }.should raise_error(PropertyInvalid, 'Property is invalid: name format, value presence')
    end

    it 'updates properties' do
      make_deployment

      property_manager.create_property('mycloud', 'foo', 'bar')
      property_manager.update_property('mycloud', 'foo', 'baz')
      property_manager.get_property('mycloud', 'foo').value.should == 'baz'
    end

    it "doesn't allow invalid updates" do
      lambda {
        property_manager.update_property('mycloud', 'foo', 'bar')
      }.should raise_error(DeploymentNotFound, "Deployment `mycloud' doesn't exist")

      make_deployment

      lambda {
        property_manager.update_property('mycloud', 'foo', 'baz')
      }.should raise_error(PropertyNotFound, "Property `foo' not found for deployment `mycloud'")

      property_manager.create_property('mycloud', 'foo', 'bar')

      lambda {
        property_manager.update_property('mycloud', 'foo', '')
      }.should raise_error(PropertyInvalid, 'Property is invalid: value presence')
    end

    it 'allows deleting properties' do
      make_deployment

      property_manager.create_property('mycloud', 'foo', 'bar')
      property_manager.delete_property('mycloud', 'foo')

      lambda {
        property_manager.get_property('mycloud', 'foo')
      }.should raise_error(PropertyNotFound)
    end

    it "doesn't allow invalid deletes" do
      lambda {
        property_manager.delete_property('mycloud', 'foo')
      }.should raise_error(DeploymentNotFound, "Deployment `mycloud' doesn't exist")

      make_deployment

      lambda {
        property_manager.delete_property('mycloud', 'foo')
      }.should raise_error(PropertyNotFound, "Property `foo' not found for deployment `mycloud'")
    end

    it 'lists all properties' do
      make_deployment

      property_manager.get_properties('mycloud').should == []

      property_manager.create_property('mycloud', 'foo', 'bar')
      property_manager.create_property('mycloud', 'password', 'secret')

      properties = property_manager.get_properties('mycloud')
      properties.size.should == 2

      [properties[0].value, properties[1].value].sort.should == %W(bar secret)
    end
  end
end
