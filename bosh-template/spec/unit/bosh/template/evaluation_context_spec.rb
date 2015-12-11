require 'spec_helper'
require 'bosh/template/evaluation_context'

module Bosh
  module Template
    describe EvaluationContext do
      def eval_template(erb, context)
        ERB.new(erb).result(context.get_binding)
      end

      before do
        @spec = {
          'job' => {
            'name' => 'foobar'
          },
          'properties' => {
            'foo' => 'bar',
            'router' => {'token' => 'zbb'},
            'vtrue' => true,
            'vfalse' => false
          },
          'links' => {
            'fake-link-1' => {'a' => 'b'},
            'fake-link-2' => {'c' => 'd'}
          },
          'index' => 0,
          'id' => 'deadbeef',
          'bootstrap' => true,
          'az' => 'foo-az',
          'resource_pool' => 'a'
        }

        @context = EvaluationContext.new(@spec)
      end

      it 'unrolls properties into OpenStruct' do
        expect(eval_template('<%= properties.foo %>', @context)).to eq('bar')
      end

      it 'retains raw_properties' do
        expect(eval_template("<%= raw_properties['router']['token'] %>", @context)).to eq('zbb')
      end

      it 'supports looking up template index' do
        expect(eval_template('<%= spec.index %>', @context)).to eq('0')
      end

      it 'supports looking up template instance id' do
        expect(eval_template('<%= spec.id %>', @context)).to eq(@context.spec.id)
      end

      it 'supports looking up template availability zone' do
        expect(eval_template('<%= spec.az %>', @context)).to eq(@context.spec.az)
        end

      it 'exposes an resource pool' do
        expect(eval_template('<%= spec.resource_pool %>', @context)).to eq('a')
      end

      it 'supports looking up whether template is bootstrap or not' do
        expect(eval_template('<%= spec.bootstrap %>', @context)).to eq('true')
      end

      it 'evaluates links' do
        expect(eval_template("<%= link('fake-link-1.a') %>", @context)).to eq('b')
        expect(eval_template("<%= link('fake-link-2.c') %>", @context)).to eq('d')
        expect(eval_template("<%= link('fake-link-2')['c'] %>", @context)).to eq('d')

        expect {
          eval_template("<%= link('fake-link-1.z') %>", @context)
        }.to raise_error(UnknownLink, "Can't find link 'fake-link-1.z'")
      end

      describe 'p' do
        it 'looks up properties' do
          expect(eval_template("<%= p('router.token') %>", @context)).to eq('zbb')
          expect(eval_template("<%= p('vtrue') %>", @context)).to eq('true')
          expect(eval_template("<%= p('vfalse') %>", @context)).to eq('false')
          expect {
            eval_template("<%= p('bar.baz') %>", @context)
          }.to raise_error(UnknownProperty, "Can't find property `[\"bar.baz\"]'")
          expect(eval_template("<%= p('bar.baz', 22) %>", @context)).to eq('22')
        end

        it 'supports hash properties' do
          expect(eval_template(<<-TMPL, @context).strip).to eq('zbb')
        <%= p(%w(a b router c))['token'] %>
          TMPL
        end

        it 'chains property lookups' do
          expect(eval_template(<<-TMPL, @context).strip).to eq('zbb')
        <%= p(%w(a b router.token c)) %>
          TMPL

          expect {
            eval_template(<<-TMPL, @context)
          <%= p(%w(a b c)) %>
            TMPL
          }.to raise_error(UnknownProperty,
                           "Can't find property `[\"a\", \"b\", \"c\"]'")

          expect(eval_template(<<-TMPL, @context).strip).to eq('22')
        <%= p(%w(a b c), 22) %>
          TMPL
        end
      end

      it "allows 'false' and 'nil' defaults for 'p' helper" do
        expect(eval_template(<<-TMPL, @context).strip).to eq('false')
      <%= p(%w(a b c), false) %>
        TMPL

        expect(eval_template(<<-TMPL, @context).strip).to eq('')
      <%= p(%w(a b c), nil) %>
        TMPL
      end

      describe 'if_p' do
        it 'works with a single property' do
          template = <<-TMPL
        <% if_p("router.token") do |token| %>
        <%= token %>
        <% end %>
          TMPL

          expect(eval_template(template, @context).strip).to eq('zbb')
        end

        it 'works with two properties' do
          template = <<-TMPL
        <% if_p("router.token", "foo") do |token, foo| %>
        <%= token %>, <%= foo %>
        <% end %>
          TMPL

          expect(eval_template(template, @context).strip).to eq('zbb, bar')
        end

        it "does not call the block if a property can't be found" do
          template = <<-TMPL
        <% if_p("router.token", "no.such.prop") do |token, none| %>
        test output
        <% end %>
          TMPL

          expect(eval_template(template, @context).strip).to eq('')
        end

        describe '.else' do
          it 'does not call the else block if all properties are found' do
            template = <<-TMPL
          <% if_p("router.token", "foo") do |token, foo| %>
          <%= token %>, <%= foo %>
          <% end.else do %>
          hidden words
          <% end %>
            TMPL

            expect(eval_template(template, @context).strip).to eq('zbb, bar')
          end

          it 'calls the else block if any of the properties are missing' do
            template = <<-TMPL
          <% if_p("router.token", "no.such.prop") do |token, none| %>
          test output
          <% end.else do %>
          visible text
          <% end %>
            TMPL

            expect(eval_template(template, @context).strip).to eq('visible text')
          end
        end

        describe '.else_if_p' do
          it 'is not called when if_p matches' do
            template = <<-TMPL
          <% if_p("router.token", "foo") do |token, foo| %>
          <%= token %>, <%= foo %>
          <% end.else_if_p("vtrue") do |v| %>
          hidden words
          <% end.else do %>
          not going to get here
          <% end %>
            TMPL

            expect(eval_template(template, @context).strip).to eq('zbb, bar')
          end

          it 'is called when if_p does not match' do
            template = <<-TMPL
          <% if_p("router.token", "no.such.prop") do |token, foo| %>
          <%= token %>, <%= foo %>
          <% end.else_if_p("vtrue") do |v| %>
          <%= v %>
          <% end.else do %>
          not going to get here
          <% end %>
            TMPL

            expect(eval_template(template, @context).strip).to eq('true')
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

            expect(eval_template(template, @context).strip).to eq('totally going to get here')
          end
        end
      end
    end
  end
end
