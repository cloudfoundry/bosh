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
        "router" => {"token" => "zbb"},
        "vtrue" => true,
        "vfalse" => false
      },
      "index" => 0,
    }

    @context = make(@spec)
  end

  it "unrolls properties into OpenStruct" do
    eval_template("<%= properties.foo %>", @context).should == "bar"
  end

  it "retains raw_properties" do
    eval_template("<%= raw_properties['router']['token'] %>", @context).
      should == "zbb"
  end

  it "supports looking up template index" do
    eval_template("<%= spec.index %>", @context).should == "0"
  end

  it "supports 'p' helper" do
    eval_template("<%= p('router.token') %>", @context).should == "zbb"

    eval_template("<%= p('vtrue') %>", @context).should == "true"
    eval_template("<%= p('vfalse') %>", @context).should == "false"
  end

  describe "returning default values" do
    it "raises an error if no default is passed in and no value or default is found in the spec" do
      expect {
        eval_template("<%= p('bar.baz') %>", @context)
      }.to raise_error(Bosh::Common::UnknownProperty,"Can't find property `[\"bar.baz\"]'")
    end

    it "should return a default value if it passed into the 'p' helper" do
      eval_template("<%= p('bar.baz', 22) %>", @context).should == "22"
    end

    it "returns the default from the spec if it's a hash with a default key, and no default is passed in" do
      @spec["properties"]["foo"] = {"default" => "default_foo"}
      @context = make(@spec)
      eval_template("<%= p('foo') %>", @context).should == "default_foo"
    end

    it "gives precedence to defaults in the spec over passed in defaults" do
      @spec["properties"]["foo"] = {"default" => "default_foo"}
      @context = make(@spec)
      eval_template("<%= p('foo', 22) %>", @context).should == "default_foo"
    end
  end

  it "supports chaining property lookup via 'p' helper" do
    eval_template(<<-TMPL, @context).strip.should == "zbb"
      <%= p(%w(a b router.token c)) %>
    TMPL

    expect {
      eval_template(<<-TMPL, @context)
        <%= p(%w(a b c)) %>
      TMPL
    }.to raise_error(Bosh::Common::UnknownProperty,
                     "Can't find property `[\"a\", \"b\", \"c\"]'")

    eval_template(<<-TMPL, @context).strip.should == "22"
      <%= p(%w(a b c), 22) %>
    TMPL
  end

  it "allows 'false' and 'nil' defaults for 'p' helper" do
    eval_template(<<-TMPL, @context).strip.should == "false"
      <%= p(%w(a b c), false) %>
    TMPL

    eval_template(<<-TMPL, @context).strip.should == ""
      <%= p(%w(a b c), nil) %>
    TMPL
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