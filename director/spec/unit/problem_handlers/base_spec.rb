require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::ProblemHandlers::Base do

  def make_by_type(type, resource_id, data)
    Bosh::Director::ProblemHandlers::Base.create_by_type(type, resource_id, data)
  end

  class FooHandler < Bosh::Director::ProblemHandlers::Base
    register_as :foo
    auto_resolution :baz

    attr_reader :message
    attr_reader :resource_id

    def initialize(resource_id, data)
      super
      @resource_id = resource_id
      @message = data["message"]
    end

    resolution :baz do
      plan { "foo baz #{@message}"}
      action do
        @message = "foo baz action complete"
      end
    end
  end

  class BarHandler < Bosh::Director::ProblemHandlers::Base
    register_as :bar
    auto_resolution :zb

    attr_reader :message
    attr_reader :resource_id

    def initialize(resource_id, data)
      super
      @resource_id = resource_id
      @message = data["message"]
    end

    resolution :baz do
      plan { "bar baz #{@message}"}
      action do
        @message = "bar baz action complete"
      end
    end

    resolution :zb do
      plan { "bar zb #{@message}" }
      action do
        @message = "bar zb action complete"
      end
    end
  end

  it "supports pluggable handlers and solutions DSL" do
    foo_handler = make_by_type(:foo, 1, { "message" => "hello" })
    bar_handler = make_by_type(:bar, 2, { "message" => "goodbye" })

    foo_handler.resolution_plan(:baz).should == "foo baz hello"
    bar_handler.resolution_plan(:baz).should == "bar baz goodbye"
    bar_handler.resolution_plan(:zb).should == "bar zb goodbye"

    foo_handler.resolutions.should == [ { :name => "baz", :plan => "foo baz hello" } ]

    bar_handler.resolutions.should ==
      [
       { :name => "baz", :plan => "bar baz goodbye" },
       { :name => "zb", :plan => "bar zb goodbye"}
      ]

    foo_handler.message.should == "hello"
    foo_handler.apply_resolution(:baz)
    foo_handler.message.should == "foo baz action complete"

    bar_handler.message.should == "goodbye"
    bar_handler.apply_resolution(:baz)
    bar_handler.message.should == "bar baz action complete"
  end

  it "supports auto-resolving" do
    foo_handler = make_by_type(:foo, 1, { "message" => "hello" })
    bar_handler = make_by_type(:bar, 2, { "message" => "goodbye" })

    bar_handler.auto_resolve
    bar_handler.message.should == "bar zb action complete"

    foo_handler.auto_resolve
    foo_handler.message.should == "foo baz action complete"
  end

end
