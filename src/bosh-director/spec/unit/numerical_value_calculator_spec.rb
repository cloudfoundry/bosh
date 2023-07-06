require 'spec_helper'

module Bosh::Director
  describe NumericalValueCalculator do
    describe '#get_numerical_value' do
      context 'when value is a string representation of an integer' do
        it 'returns the integer value' do
          expect(NumericalValueCalculator.get_numerical_value('10', 10)).to eq(10)
        end
      end

      context 'when value is a percentage' do
        it 'returns that percentage of size' do
          expect(NumericalValueCalculator.get_numerical_value('33%', 10)).to eq(3)
        end
      end

      context 'when value is not the right format' do
        it 'raises' do
          expect { NumericalValueCalculator.get_numerical_value('foobar', 10) }.to raise_error(/cannot be calculated/)
        end
      end
    end
  end
end
