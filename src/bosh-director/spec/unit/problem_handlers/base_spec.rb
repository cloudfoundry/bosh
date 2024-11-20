require 'spec_helper'

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

    def description
      message
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

    expect(foo_handler.resolution_plan(:baz)).to eq("foo baz hello")
    expect(bar_handler.resolution_plan(:baz)).to eq("bar baz goodbye")
    expect(bar_handler.resolution_plan(:zb)).to eq("bar zb goodbye")

    expect(foo_handler.resolutions).to eq([ { name: "baz", plan: "foo baz hello" } ])

    expect(bar_handler.resolutions).to eq(
      [
       { name: "baz", plan: "bar baz goodbye" },
       { name: "zb", plan: "bar zb goodbye" }
      ]
    )

    expect(foo_handler.message).to eq("hello")
    foo_handler.apply_resolution(:baz)
    expect(foo_handler.message).to eq("foo baz action complete")

    expect(bar_handler.message).to eq("goodbye")
    bar_handler.apply_resolution(:baz)
    expect(bar_handler.message).to eq("bar baz action complete")
  end

  it "supports auto-resolving" do
    foo_handler = make_by_type(:foo, 1, { "message" => "hello" })
    bar_handler = make_by_type(:bar, 2, { "message" => "goodbye" })

    bar_handler.auto_resolve
    expect(bar_handler.message).to eq("bar zb action complete")

    foo_handler.auto_resolve
    expect(foo_handler.message).to eq("foo baz action complete")
  end

  it "can be queried from the model" do
    problem = FactoryBot.create(:models_deployment_problem,
                                type: "foo",
                                resource_id: 1,
                                data_json: JSON.generate("message" => "hello"))

    expect(problem.description).to eq("hello")
    expect(problem.resolutions).to eq([ { name: "baz", plan: "foo baz hello" } ])
  end

end
