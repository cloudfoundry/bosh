require 'spec_helper'

describe Bosh::Cli::NameIdPair do
  describe '.parse' do
    invalid_error = 'must be in the form name/id'
    nil_error = 'str must not be nil'

    context 'when given value contains no slashes' do
      it 'raises argument error' do
        expect { described_class.parse('non-slash') }
          .to raise_error(ArgumentError, "\"non-slash\" #{invalid_error}")
      end
    end

    context 'when given value contains 1 slash' do
      context 'when name and id are not empty' do
        it 'splits given value into name and id' do
          pair = described_class.parse('name/id')
          expect(pair.name).to eq('name')
          expect(pair.id).to eq('id')
        end
      end

      context 'when name is empty' do
        it 'raises argument error' do
          expect { described_class.parse('/id') }
            .to raise_error(ArgumentError, "\"/id\" #{invalid_error}")
        end
      end

      context 'when id is empty' do
        it 'raises argument error' do
          expect { described_class.parse('name/') }
            .to raise_error(ArgumentError, "\"name/\" #{invalid_error}")
        end
      end

      context 'when name and id are empty' do
        it 'raises argument error' do
          expect { described_class.parse('/') }
            .to raise_error(ArgumentError, "\"/\" #{invalid_error}")
        end
      end
    end

    context 'when given value contains >1 slash' do
      it 'splits given value into name that has a slash and a id' do
        pair = described_class.parse('name/name/id')
        expect(pair.name).to eq('name/name')
        expect(pair.id).to eq('id')
      end
    end

    context 'when given value is an empty string' do
      it 'raises argument error' do
        expect { described_class.parse('') }.to raise_error(ArgumentError, "\"\" #{invalid_error}")
      end
    end

    context 'when given value is nil' do
      it 'raises argument error' do
        expect { described_class.parse(nil) }.to raise_error(ArgumentError, nil_error)
      end
    end
  end
end
