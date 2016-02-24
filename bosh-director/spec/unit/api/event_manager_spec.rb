require 'spec_helper'

describe Bosh::Director::Api::EventManager do
  let(:manager) { described_class.new }

  describe '#store_event' do
    it 'should create a new event model' do
      expect {
        described_class.new.create_event({:user => "user", :action => "action", :object_type => "deployment", :object_name => "dep"})
      }.to change {
        Bosh::Director::Models::Event.count
      }.from(0).to(1)
    end
  end

  describe '#event_to_hash' do
    it 'should not pass values are equal to nil' do
      Bosh::Director::Models::Event.make(
          "user"        => "test",
          "action"      => "create",
          "object_type" => "deployment",
          "object_name" => "depl1",
          "error"       => nil,
          "task"        => nil,
          "deployment"  => nil,
          "instance"    => nil,
          "parent_id"   => nil
      )
      expect(manager.event_to_hash(Bosh::Director::Models::Event.first)).not_to include("error", "task", "deployment", "instance", "parent_id")
    end

    it 'should pass ids as String' do
      Bosh::Director::Models::Event.make(
          "parent_id"   => 2,
          "user"        => "test",
          "action"      => "create",
          "object_type" => "deployment",
          "object_name" => "depl1",
      )
      expect(manager.event_to_hash(Bosh::Director::Models::Event.first)).to include("id" => "1", "parent_id" => "2")
    end
  end
end
