require 'spec_helper'

describe Bosh::Director::Links::LinksManagerFactory do

  it 'has a static method to create itself' do
    factory = Bosh::Director::Links::LinksManagerFactory.create
    expect(factory.kind_of?Bosh::Director::Links::LinksManagerFactory).to eq(true)
  end

  describe '#create_manager' do
    subject(:manager_factory) { Bosh::Director::Links::LinksManagerFactory.create }

    it 'creates a new LinksManager Instance' do
      manager_created = manager_factory.create_manager
      expect(manager_created.kind_of?Bosh::Director::Links::LinksManager).to eq(true)
    end

    it 'creates a different instances of link manager when called multiple times' do
      manager_1 = manager_factory.create_manager
      manager_2 = manager_factory.create_manager

      expect(manager_1).to_not equal(manager_2)
    end
  end
end
