require 'spec_helper'

describe Bosh::Cli::NameVersionPair do
  describe '.parse' do
    invalid_error = 'must be in the form name/version'
    nil_error = 'str must not be nil'

    context 'when given value contains no slashes' do
      it 'raises argument error' do
        expect { described_class.parse('non-slash') }
          .to raise_error(ArgumentError, "\"non-slash\" #{invalid_error}")
      end
    end

    context 'when given value contains 1 slash' do
      context 'when name and version are not empty' do
        it 'splits given value into name and version' do
          pair = described_class.parse('name/version')
          expect(pair.name).to eq('name')
          expect(pair.version).to eq('version')
        end
      end

      context 'when name is empty' do
        it 'raises argument error' do
          expect { described_class.parse('/version') }
            .to raise_error(ArgumentError, "\"/version\" #{invalid_error}")
        end
      end

      context 'when version is empty' do
        it 'raises argument error' do
          expect { described_class.parse('name/') }
            .to raise_error(ArgumentError, "\"name/\" #{invalid_error}")
        end
      end

      context 'when name and version are empty' do
        it 'raises argument error' do
          expect { described_class.parse('/') }
            .to raise_error(ArgumentError, "\"/\" #{invalid_error}")
        end
      end
    end

    context 'when given value contains >1 slash' do
      it 'splits given value into name that has a slash and a version' do
        pair = described_class.parse('name/name/version')
        expect(pair.name).to eq('name/name')
        expect(pair.version).to eq('version')
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
