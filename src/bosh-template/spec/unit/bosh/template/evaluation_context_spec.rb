require 'spec_helper'
require 'bosh/template/evaluation_context'
require 'bosh/template/evaluation_link_instance'
require 'bosh/template/evaluation_link'
require 'common/deep_copy'

module Bosh
  module Template
    describe EvaluationContext do
      def eval_template(erb, context)
        ERB.new(erb).result(context.get_binding)
      end

      let(:dns_encoder) { double('some dns encoder', encode_query: 'some.fqdn') }
      let(:manual_link_dns_encoder) do
        manual_link_dns_encoder = double(Bosh::Template::ManualLinkDnsEncoder, encode_query: 'some.fqdn')
        allow(Bosh::Template::ManualLinkDnsEncoder).to receive(:new).and_return(manual_link_dns_encoder)
        manual_link_dns_encoder
      end

      let(:instances) { [{ 'address' => '123.456.789.101', 'properties' => { 'prop1' => 'value' } }] }
      let(:use_short_dns_addresses) { false }
      let(:use_link_dns_names) { false }

      let(:spec) do
        {
          'job' => {
            'name' => 'foobar',
          },
          'properties' => {
            'foo' => 'bar',
            'router' => { 'token' => 'zbb' },
            'vtrue' => true,
            'vfalse' => false,
          },
          'links' => {
            'fake-link-1' => {
              'deployment_name' => 'fake-deployment',
              'instance_group' => 'fake-instance-group-1',
              'default_network' => 'default',
              'domain' => 'otherbosh',
              'instances' => instances,
              'use_short_dns_addresses' => use_short_dns_addresses,
              'link_provider_name' => 'provider1',
              'link_provider_type' => 'link_type1',
            },
            'fake-link-2' => {
              'deployment_name' => 'fake-deployment',
              'instance_group' => 'fake-instance-group-2',
              'default_network' => 'default',
              'address' => 'some-address',
              'domain' => 'otherbosh',
              'instances' => [
                'address' => '123.456.789.102',
                'properties' => { 'prop2' => 'value' },
              ],
              'link_provider_name' => '',
              'link_provider_original_name' => 'orig_name1',
              'link_provider_type' => 'link_type2',
            },
            'fake-link-3' => {
              'deployment_name' => 'fake-deployment',
              'instance_group' => 'fake-instance-group-3',
              'group_name' => 'link-group-name-3',
              'use_link_dns_names' => use_link_dns_names,
              'default_network' => 'default',
              'domain' => 'otherbosh',
              'instances' => [
                'address' => '123.456.789.103',
                'properties' => { 'prop3' => 'value' },
              ],
              'link_provider_name' => nil,
              'link_provider_original_name' => '',
              'link_provider_type' => '',
            },
            'fake-link-4' => {
              'deployment_name' => 'fake-deployment',
              'instance_group' => 'fake-instance-group-2',
              'default_network' => 'default',
              'domain' => 'otherbosh',
              'instances' => [
                'address' => '123.456.789.102',
                'properties' => { 'prop2' => 'value' },
              ],
              'link_provider_name' => '',
              'link_provider_original_name' => 'orig_name1',
              'link_provider_type' => 'link_type2',
            },
          },
          'networks' => {
            'network1' => {
              'foo' => 'bar',
              'ip' => '192.168.0.1',
            },
            'network2' => {
              'baz' => 'bang',
              'ip' => '10.10.10.10',
            },
          },
          'index' => 0,
          'id' => 'deadbeef',
          'bootstrap' => true,
          'az' => 'foo-az',
          'release' => {
            'name' => 'test',
            'version' => '1.0',
          },
        }
      end

      let(:evaluation_context) do
        EvaluationContext.new(Bosh::Common::DeepCopy.copy(spec), dns_encoder)
      end

      context 'operator ==' do
        let(:other_evaluation_context) do
          EvaluationContext.new(Bosh::Common::DeepCopy.copy(spec), dns_encoder)
        end

        context 'when nothing changes' do
          it 'returns true' do
            expect(evaluation_context == other_evaluation_context).to equal(true)
          end
        end

        context 'when spec changes' do
          it 'returns false' do
            evaluation_context.spec['job']['name'] = 'modified_job_name'
            expect(evaluation_context == other_evaluation_context).to equal(false)
          end
        end

        context 'when properties changes' do
          it 'returns false' do
            evaluation_context.properties.foo = 'modified_bar'
            expect(evaluation_context == other_evaluation_context).to equal(false)
          end
        end

        context 'when raw_properties changes' do
          it 'returns false' do
            evaluation_context.raw_properties['foo'] = 'modified_bar'
            expect(evaluation_context == other_evaluation_context).to equal(false)
          end
        end

        context 'when name changes' do
          it 'returns false' do
            evaluation_context.name << 'modified_name'
            expect(evaluation_context == other_evaluation_context).to equal(false)
          end
        end

        context 'when index changes' do
          module MakeIndexAccessible
            refine Bosh::Template::EvaluationContext do
              def modify_index
                @index = 42
              end
            end
          end
          using MakeIndexAccessible

          it 'returns false' do
            evaluation_context.modify_index
            expect(evaluation_context.index).to equal(42)
            expect(evaluation_context == other_evaluation_context).to equal(false)
          end
        end

        context 'when instance variables are modified' do
          all_members = EvaluationContext.new({}, nil).instance_variables.map { |var| var.to_s.tr('@', '') }
          private_members = %w[dns_encoder links]
          public_members = all_members - private_members
          public_members.each do |member|
            it "returns false when #{member} is modified" do
              instance_eval <<-END_EVAL, __FILE__, __LINE__ + 1
                class Bosh::Template::EvaluationContext
                  def modify_#{member}
                   @#{member} = 'foo'
                  end
                end
              END_EVAL
              evaluation_context.send("modify_#{member}")
              expect(evaluation_context == other_evaluation_context).to(
                equal(false),
                "Modification of #{member} not detected by == operator. If it is a private member, add it to private_members",
              )
            end
          end
        end
      end

      context 'openstruct' do
        it 'should support the ip address snippet widely used by release authors' do
          expect(
            eval_template('<%= spec.networks.send(spec.networks.methods(false).first).ip %>', evaluation_context),
          ).to eq('192.168.0.1')
        end

        it 'retains raw_properties' do
          expect(eval_template("<%= raw_properties['router']['token'] %>", evaluation_context)).to eq('zbb')
        end

        it 'supports looking up template index' do
          expect(eval_template('<%= spec.index %>', evaluation_context)).to eq('0')
        end

        it 'supports looking up template instance id' do
          expect(eval_template('<%= spec.id %>', evaluation_context)).to eq(evaluation_context.spec.id)
        end

        it 'supports looking up template availability zone' do
          expect(eval_template('<%= spec.az %>', evaluation_context)).to eq(evaluation_context.spec.az)
        end

        it 'supports looking up whether template is bootstrap or not' do
          expect(eval_template('<%= spec.bootstrap %>', evaluation_context)).to eq('true')
        end

        it 'supports looking up template release name' do
          expect(eval_template('<%= spec.release.name %>', evaluation_context)).to eq(evaluation_context.spec.release.name)
        end

        it 'supports looking up template release version' do
          expect(eval_template('<%= spec.release.version %>', evaluation_context)).to eq(evaluation_context.spec.release.version)
        end
      end

      it 'evaluates templates' do
        expect(eval_template('a', evaluation_context)).to eq('a')
      end

      context 'links' do
        let(:instance1) { double(Bosh::Template::EvaluationLinkInstance) }
        let(:instance2) { double(Bosh::Template::EvaluationLinkInstance, address: 'instance2_address', p: 'p2') }
        let(:evaluation_link1) { double(Bosh::Template::EvaluationLink, instances: [instance1]) }
        let(:evaluation_link2) { double(Bosh::Template::EvaluationLink, instances: [instance2]) }

        before do
          allow(EvaluationLinkInstance).to receive(:new).with(
            nil,
            nil,
            nil,
            nil,
            '123.456.789.101',
            { 'prop1' => 'value' },
            nil,
          ).and_return instance1

          allow(EvaluationLink).to receive(:new).with(
            [instance1],
            nil,
            'fake-instance-group-1',
            'instance-group',
            'default',
            'fake-deployment',
            'otherbosh',
            dns_encoder,
            false,
          ).and_return evaluation_link1
        end

        before do
          allow(EvaluationLinkInstance).to receive(:new).with(
            nil,
            nil,
            nil,
            nil,
            '123.456.789.102',
            { 'prop2' => 'value' },
            nil,
          ).and_return instance2

          allow(EvaluationLink).to receive(:new).with(
            [instance2],
            nil,
            'fake-instance-group-2',
            'instance-group',
            'default',
            'fake-deployment',
            'otherbosh',
            manual_link_dns_encoder,
            false,
          ).and_return evaluation_link2
        end

        describe 'link' do
          it 'evaluates links' do
            expect(evaluation_context.link('fake-link-1')).to eq(evaluation_link1)
            expect(evaluation_context.link('fake-link-2')).to eq(evaluation_link2)
          end

          it 'should throw a nice error when a link cannot be found' do
            expect do
              evaluation_context.link('invisi-link')
            end.to raise_error(UnknownLink, "Can't find link 'invisi-link'")
          end

          context 'with use_link_dns_names enabled' do
            let(:use_link_dns_names) { true }
            let(:instance3) { double(Bosh::Template::EvaluationLinkInstance) }
            let(:evaluation_link3) { double(Bosh::Template::EvaluationLink, instances: [instance3]) }

            before do
              allow(EvaluationLinkInstance).to receive(:new).with(
                nil,
                nil,
                nil,
                nil,
                '123.456.789.103',
                { 'prop3' => 'value' },
                nil,
              ).and_return instance3

              allow(EvaluationLink).to receive(:new).with(
                [instance3],
                nil,
                'link-group-name-3',
                'link',
                'default',
                'fake-deployment',
                'otherbosh',
                dns_encoder,
                false,
              ).and_return evaluation_link3
            end

            it 'evaluates links' do
              expect(evaluation_context.link('fake-link-3')).to eq(evaluation_link3)
            end
          end

        end

        describe 'if_link' do
          it 'works when link is found' do
            evaluation_context.if_link('fake-link-1') do |link|
              expect(link.instances).to eq([instance1])
            end
          end

          it "does not call the block if a link can't be found" do
            evaluation_context.if_link('imaginary-link-1') do
              raise 'should never get here'
            end
          end

          describe '.else' do
            it 'does not call the else block if link is found' do
              evaluation_context.if_link('fake-link-1') do |link|
                expect(link.instances).to eq([instance1])
              end.else do
                raise 'should never get here'
              end
            end

            it 'calls the else block if the link is missing' do
              expect do
                evaluation_context.if_link('imaginary-link-1') do
                  raise 'should not get here'
                end.else do
                  raise 'got here'
                end
              end.to raise_error 'got here'
            end
          end

          describe '.else_if_link' do
            it 'is not called when if_link matches' do
              evaluation_context.if_link('fake-link-1') do |link|
                expect(link.instances).to eq([instance1])
              end.else_if_link('should never get here link') do
                raise 'it should never get here pt 1'
              end.else do
                raise 'it should never get here pt 2'
              end
            end

            it 'is called when if_link does not match' do
              evaluation_context.if_link('imaginary-link') do
                raise 'it should never get here pt 1'
              end.else_if_link('fake-link-1') do |link|
                expect(link.instances).to eq([instance1])
              end.else do
                raise 'it should never get here pt 2'
              end
            end

            it "calls else when its conditions aren't met" do
              expect do
                evaluation_context.if_link('imaginary-link-1') do
                  raise 'it should never get here pt 1'
                end.else_if_link('imaginary-link-2') do
                  raise 'it should never get here pt 2'
                end.else do
                  raise 'got to the else'
                end
              end.to raise_error 'got to the else'
            end
          end
        end
      end

      context 'p and if_p' do
        describe 'p' do
          it 'looks up properties' do
            expect(evaluation_context.p('router.token')).to eq('zbb')
            expect(evaluation_context.p('vtrue')).to eq(true)
            expect(evaluation_context.p('vfalse')).to eq(false)
          end

          it 'returns the default value if the property doesnt exist and there was a default value given' do
            expect(evaluation_context.p('bar.baz', 22)).to eq(22)
            expect(evaluation_context.p(%w[a b c], 22)).to eq(22)
          end

          it 'throws an UnknowProperty error if the property does not exist' do
            expect do
              evaluation_context.p('bar.baz')
            end.to raise_error(Bosh::Template::UnknownProperty, "Can't find property '[\"bar.baz\"]'")

            expect do
              evaluation_context.p(%w[a b c])
            end.to raise_error(Bosh::Template::UnknownProperty,
                               "Can't find property '[\"a\", \"b\", \"c\"]'")
          end

          it 'supports hash properties' do
            expect(evaluation_context.p(%w[a b router c])['token']).to eq('zbb')
          end

          it 'chains property lookups' do
            expect(evaluation_context.p(%w[a b router.token c])).to eq('zbb')
          end

          it "allows booleans and 'nil' defaults for 'p' helper" do
            expect(evaluation_context.p(%w[a b c], false)).to eq(false)
            expect(evaluation_context.p(%w[a b c], true)).to eq(true)
            expect(evaluation_context.p(%w[a b c], nil)).to eq(nil)
          end
        end

        describe 'if_p' do
          it 'works with a single property' do
            evaluation_context.if_p('router.token') do |p|
              expect(p).to eq('zbb')
            end
          end

          it 'works with two properties' do
            evaluation_context.if_p('router.token', 'foo') do |p1, p2|
              expect(p1).to eq('zbb')
              expect(p2).to eq('bar')
            end
          end

          it "does not call the block if any property can't be found" do
            evaluation_context.if_p('router.token', 'nonexistent.prop') do
              raise 'doesnt blow up'
            end
          end

          describe '.else' do
            it 'does not call the else block if all properties are found' do
              evaluation_context.if_p('router.token', 'foo') do |p1, p2|
                expect(p1).to eq('zbb')
                expect(p2).to eq('bar')
              end.else do
                raise 'doesnt blow up'
              end
            end

            it 'calls the else block if any of the properties are missing' do
              expect do
                evaluation_context.if_p('router.token', 'nonexistent.prop') do
                  raise 'doesnt blow up'
                end.else do
                  raise 'be cool?'
                end
              end.to raise_error 'be cool?'
            end
          end

          describe '.else_if_p' do
            it 'is not called when if_p matches' do
              evaluation_context.if_p('router.token', 'foo') do |token, foo|
                expect(token).to eq('zbb')
                expect(foo).to eq('bar')
              end.else_if_p('vtrue') do
                raise 'no get here'
              end.else do
                raise 'nor here'
              end
            end

            it 'is called when if_p does not match' do
              evaluation_context.if_p('nonexistent.prop') do
                raise 'im not gonna pop'
              end.else_if_p('vtrue') do |v|
                expect(v).to be_truthy
              end.else do
                raise 'not gonna happen, seriously'
              end
            end

            it "calls else when its conditions aren't met" do
              expect do
                evaluation_context.if_p('nonexistent.prop') do
                  raise 'im not gonna pop'
                end.else_if_p('401.prop') do
                  raise 'not gonna happen, seriously'
                end.else do
                  raise 'catch me if you can'
                end
              end.to raise_error 'catch me if you can'
            end
          end
        end
      end
    end
  end
end
