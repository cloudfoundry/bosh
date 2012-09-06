# Copyright (c) 2012 VMware, Inc.

require "spec_helper"
require "common/properties"

describe Bosh::Common::TemplateEvaluationContext do

  def eval_template(erb, context)
    ERB.new(erb).result(context.get_binding)
  end

  def make(spec)
    Bosh::Common::TemplateEvaluationContext.new(spec)
  end

  before(:each) do
    @spec = {
      "job" => {
        "name" => "foobar"
      },
      "properties" => {
        "foo" => "bar",
        "router" => {"token" => "zbb"}
      },
      "index" => 0,
    }

    @context = make(@spec)
  end

  it "unrolls properties into OpenStruct" do
    eval_template("<%= properties.foo %>", @context).should == "bar"
  end

  it "supports looking up template index" do
    eval_template("<%= spec.index %>", @context).should == "0"
  end

  it "supports 'p' helper" do
    eval_template("<%= p('router.token') %>", @context).should == "zbb"
    expect {
      eval_template("<%= p('bar.baz') %>", @context)
    }.to raise_error(Bosh::Common::UnknownProperty)

    eval_template("<%= p('bar.baz', 22) %>", @context).should == "22"
  end

  it "supports 'if_p' helper" do
    template = <<-TMPL
      <% if_p("router.token") do |token| %>
      <%= token %>
      <% end %>
    TMPL

    eval_template(template, @context).strip.should == "zbb"

    template = <<-TMPL
      <% if_p("router.token", "foo") do |token, foo| %>
      <%= token %>, <%= foo %>
      <% end %>
    TMPL

    eval_template(template, @context).strip.should == "zbb, bar"

    template = <<-TMPL
      <% if_p("router.token", "no.such.prop") do |token, none| %>
      test output
      <% end %>
    TMPL

    eval_template(template, @context).strip.should == ""
  end

end