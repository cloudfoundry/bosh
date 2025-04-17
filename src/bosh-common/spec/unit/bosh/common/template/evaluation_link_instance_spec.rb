require 'spec_helper'

module Bosh::Common::Template
  describe EvaluationLinkInstance do
    subject do
      EvaluationLinkInstance.new(
        'name',
        'index',
        'id',
        'az',
        'address',
        properties,
        'bootstrap',
      )
    end

    let(:properties) do
      {
        'prop1' => {
          'nested1' => 'val1',
          'nested2' => 'val2',
        },
        'prop2' => {
          'nested3' => 'val3',
        },
        'prop3' => {
          'nested4' => 'val4',
        },
      }
    end

    it 'knows its attributes' do
      expect(subject.name).to eq('name')
      expect(subject.index).to eq('index')
      expect(subject.id).to eq('id')
      expect(subject.az).to eq('az')
      expect(subject.address).to eq('address')
      expect(subject.properties).to eq(properties)
      expect(subject.bootstrap).to eq('bootstrap')
    end

    context 'when properties are defined' do
      context 'p' do
        it 'can find a property' do
          expect(subject.p('prop1.nested2')).to eq('val2')
          expect(subject.p('prop2.nested3')).to eq('val3')
        end

        it 'raises an error when asked for a property which does not exist' do
          expect do
            subject.p('vroom')
          end.to raise_error UnknownProperty, "Can't find property '[\"vroom\"]'"
        end

        it 'allows setting a default instead of raising an error if the key is not found' do
          expect(subject.p('prop1.nestedX', 'default_value')).to eq('default_value')
        end

        it 'raises an UnknownProperty error if you pass more than two' \
             ' arguments and the first one is not present' do
          expect do
            subject.p('vroom', 'vroom', 'vroom')
          end.to raise_error UnknownProperty, "Can't find property '[\"vroom\"]'"
        end
      end

      context 'if_p' do
        let(:active_else_block) { double(:active_else_block) }
        let(:inactive_else_block) { double(:inactive_else_block) }

        before do
          allow(EvaluationContext::ActiveElseBlock).to receive(:new)
                                                         .with(subject)
                                                         .and_return active_else_block
          allow(EvaluationContext::InactiveElseBlock).to receive(:new)
                                                           .and_return inactive_else_block
        end

        it 'returns an active else block if any of the properties are not present' do
          expect(
            subject.if_p('prop1.nested1', 'prop2.doesntexist') {},
          ).to eq(active_else_block)
        end

        it 'yields the values of the requested properties' do
          subject.if_p('prop1.nested1', 'prop1.nested2', 'prop2.nested3') do |*values|
            expect(values).to eq(%w[val1 val2 val3])
          end
        end

        it 'returns an inactive else block' do
          expect(
            subject.if_p('prop1.nested1') {},
          ).to eq(inactive_else_block)
        end
      end
    end
  end
end
