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

  describe 'p' do
    it 'looks up properties' do
      eval_template("<%= p('router.token') %>", @context).should == "zbb"

      eval_template("<%= p('vtrue') %>", @context).should == "true"
      eval_template("<%= p('vfalse') %>", @context).should == "false"
      expect {
        eval_template("<%= p('bar.baz') %>", @context)
      }.to raise_error(Bosh::Common::UnknownProperty, "Can't find property `[\"bar.baz\"]'")
      eval_template("<%= p('bar.baz', 22) %>", @context).should == "22"
    end

    it 'supports hash properties' do
      eval_template(<<-TMPL, @context).strip.should == "zbb"
        <%= p(%w(a b router c))['token'] %>
      TMPL
    end

    it 'chains property lookups' do
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
  end

  it "allows 'false' and 'nil' defaults for 'p' helper" do
    eval_template(<<-TMPL, @context).strip.should == "false"
      <%= p(%w(a b c), false) %>
    TMPL

    eval_template(<<-TMPL, @context).strip.should == ""
      <%= p(%w(a b c), nil) %>
    TMPL
  end

  describe 'if_p' do
    it "works with a single property" do
      template = <<-TMPL
        <% if_p("router.token") do |token| %>
        <%= token %>
        <% end %>
      TMPL

      eval_template(template, @context).strip.should == "zbb"
    end

    it "works with two properties" do
      template = <<-TMPL
        <% if_p("router.token", "foo") do |token, foo| %>
        <%= token %>, <%= foo %>
        <% end %>
      TMPL

      eval_template(template, @context).strip.should == "zbb, bar"
    end

    it "does not call the block if a property can't be found" do
      template = <<-TMPL
        <% if_p("router.token", "no.such.prop") do |token, none| %>
        test output
        <% end %>
      TMPL

      eval_template(template, @context).strip.should == ""
    end

    describe '.else' do
      it "does not call the else block if all properties are found" do
        template = <<-TMPL
          <% if_p("router.token", "foo") do |token, foo| %>
          <%= token %>, <%= foo %>
          <% end.else do %>
          hidden words
          <% end %>
        TMPL

        eval_template(template, @context).strip.should == "zbb, bar"
      end

      it "calls the else block if any of the properties are missing" do
        template = <<-TMPL
          <% if_p("router.token", "no.such.prop") do |token, none| %>
          test output
          <% end.else do %>
          visible text
          <% end %>
        TMPL

        eval_template(template, @context).strip.should == "visible text"
      end
    end

    describe '.else_if_p' do
      it "is not called when if_p matches" do
        template = <<-TMPL
          <% if_p("router.token", "foo") do |token, foo| %>
          <%= token %>, <%= foo %>
          <% end.else_if_p("vtrue") do |v| %>
          hidden words
          <% end.else do %>
          not going to get here
          <% end %>
        TMPL

        eval_template(template, @context).strip.should == "zbb, bar"
      end

      it "is called when if_p does not match" do
        template = <<-TMPL
          <% if_p("router.token", "no.such.prop") do |token, foo| %>
          <%= token %>, <%= foo %>
          <% end.else_if_p("vtrue") do |v| %>
          <%= v %>
          <% end.else do %>
          not going to get here
          <% end %>
        TMPL

        eval_template(template, @context).strip.should == "true"
      end

      it "calls else when its conditions aren't met" do
        template = <<-TMPL
          <% if_p("router.token", "no.such.prop") do |token, foo| %>
          <%= token %>, <%= foo %>
          <% end.else_if_p("other.missing.prop") do |bar| %>
          <%= bar %>
          <% end.else do %>
          totally going to get here
          <% end %>
        TMPL

        eval_template(template, @context).strip.should == "totally going to get here"
      end
    end
  end
end
