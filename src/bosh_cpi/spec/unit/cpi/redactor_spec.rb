require 'spec_helper'

describe Bosh::Cpi::Redactor do
  subject { Bosh::Cpi::Redactor }
  let(:hash) do
    {
      'a' => {
        'b' => {
          'property' => 'secret'
        }
      },
      'x' => {
        'y' => {
          'property' => 'secret2'
        }
      }
    }
  end
  let(:hash_with_symbols) do
    {
      :a => {
        :b => {
          :property => 'secret'
        }
      },
      :x => {
        :y => {
          :property => 'secret2'
        }
      }
    }
  end

  describe '.redact!' do
    it 'redacts given paths from the given hash' do
      redacted_hash = subject.redact!(hash, 'a.b.property', 'x.y.property')

      expect(redacted_hash).to be(hash)
      expect(hash['a']['b']['property']).to eq('<redacted>')
      expect(hash['x']['y']['property']).to eq('<redacted>')
    end

    context 'when given property does not exist' do
      let(:hash) { {} }
      it 'does not add the redacted string' do
        subject.redact!(hash, 'property')

        expect(hash['property']).to be_nil
      end
    end

    context 'given hash with symbols' do
      it 'does not redact a given path from the given hash' do
        redacted_hash = subject.redact!(hash_with_symbols, 'a.b.property')

        expect(redacted_hash).to be(hash_with_symbols)
        expect(hash_with_symbols[:a][:b][:property]).to eq('secret')
        expect(hash_with_symbols[:x][:y][:property]).to eq('secret2')
      end
    end
  end

  describe '.clone_and_redact' do
    it 'clones and redacts given paths from the given hash' do
      redacted_hash = subject.clone_and_redact(hash, 'a.b.property', 'x.y.property')

      expect(redacted_hash).to_not be(hash)
      expect(redacted_hash['a']['b']['property']).to eq('<redacted>')
      expect(redacted_hash['x']['y']['property']).to eq('<redacted>')
      expect(hash['a']['b']['property']).to eq('secret')
      expect(hash['x']['y']['property']).to eq('secret2')
    end

    context 'given hash with symbols' do
      it 'clones and redacts given paths from the given hash' do
        redacted_hash = subject.clone_and_redact(hash_with_symbols, 'a.b.property', 'x.y.property')

        expect(redacted_hash).to_not be(hash_with_symbols)
        expect(redacted_hash['a']['b']['property']).to eq('<redacted>')
        expect(redacted_hash['x']['y']['property']).to eq('<redacted>')
        expect(hash_with_symbols[:a][:b][:property]).to eq('secret')
        expect(hash_with_symbols[:x][:y][:property]).to eq('secret2')
      end
    end
  end
end