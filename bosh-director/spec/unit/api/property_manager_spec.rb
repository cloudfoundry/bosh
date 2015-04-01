require 'spec_helper'

module Bosh::Director
  describe Api::PropertyManager do
    subject(:property_manager) { Api::PropertyManager.new(Api::DeploymentManager.new) }

    def make_deployment
      Models::Deployment.make(name: 'mycloud')
    end

    it 'creates/reads properties' do
      make_deployment
      property_manager.create_property('mycloud', 'foo', 'bar')
      expect(property_manager.get_property('mycloud', 'foo').value).to eq('bar')
    end

    it "doesn't allow duplicate property names" do
      make_deployment
      property_manager.create_property('mycloud', 'foo', 'bar')

      expect {
        property_manager.create_property('mycloud', 'foo', 'baz')
      }.to raise_error(PropertyAlreadyExists, "Property `foo' already exists for deployment `mycloud'")
    end

    it "doesn't allow invalid properties" do
      expect {
        property_manager.create_property('mycloud', 'foo', 'bar')
      }.to raise_error(DeploymentNotFound, "Deployment `mycloud' doesn't exist")

      make_deployment

      expect {
        property_manager.create_property('mycloud', 'foo$', 'bar')
      }.to raise_error(PropertyInvalid, 'Property is invalid: name format')

      expect {
        property_manager.create_property('mycloud', '', 'bar')
      }.to raise_error(PropertyInvalid, 'Property is invalid: name presence')

      expect {
        property_manager.create_property('mycloud', 'foo', '')
      }.to raise_error(PropertyInvalid, 'Property is invalid: value presence')

      expect {
        property_manager.create_property('mycloud', 'foo$', '')
      }.to raise_error(PropertyInvalid, 'Property is invalid: name format, value presence')
    end

    it 'updates properties' do
      make_deployment

      property_manager.create_property('mycloud', 'foo', 'bar')
      property_manager.update_property('mycloud', 'foo', 'baz')
      expect(property_manager.get_property('mycloud', 'foo').value).to eq('baz')
    end

    it "doesn't allow invalid updates" do
      expect {
        property_manager.update_property('mycloud', 'foo', 'bar')
      }.to raise_error(DeploymentNotFound, "Deployment `mycloud' doesn't exist")

      make_deployment

      expect {
        property_manager.update_property('mycloud', 'foo', 'baz')
      }.to raise_error(PropertyNotFound, "Property `foo' not found for deployment `mycloud'")

      property_manager.create_property('mycloud', 'foo', 'bar')

      expect {
        property_manager.update_property('mycloud', 'foo', '')
      }.to raise_error(PropertyInvalid, 'Property is invalid: value presence')
    end

    it 'allows deleting properties' do
      make_deployment

      property_manager.create_property('mycloud', 'foo', 'bar')
      property_manager.delete_property('mycloud', 'foo')

      expect {
        property_manager.get_property('mycloud', 'foo')
      }.to raise_error(PropertyNotFound)
    end

    it "doesn't allow invalid deletes" do
      expect {
        property_manager.delete_property('mycloud', 'foo')
      }.to raise_error(DeploymentNotFound, "Deployment `mycloud' doesn't exist")

      make_deployment

      expect {
        property_manager.delete_property('mycloud', 'foo')
      }.to raise_error(PropertyNotFound, "Property `foo' not found for deployment `mycloud'")
    end

    it 'lists all properties' do
      make_deployment

      expect(property_manager.get_properties('mycloud')).to eq([])

      property_manager.create_property('mycloud', 'foo', 'bar')
      property_manager.create_property('mycloud', 'password', 'secret')

      properties = property_manager.get_properties('mycloud')
      expect(properties.size).to eq(2)

      expect([properties[0].value, properties[1].value].sort).to eq(%W(bar secret))
    end
  end
end
