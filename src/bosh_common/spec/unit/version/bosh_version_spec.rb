require 'spec_helper'

module Bosh::Common::Version
  describe BoshVersion do

    it 'extends SemiSemanticVersion' do
      expect(described_class.parse('1.0.1')).to be_kind_of(SemiSemanticVersion)
    end

    describe 'parse' do
      it 'creates a new object' do
        expect(described_class.parse('1.0.1')).to be_instance_of(described_class)
      end

      it 'fails for non-SemiSemantic version' do
        expect{described_class.parse(nil)}.to raise_error(ArgumentError)
        expect{described_class.parse('')}.to raise_error(ArgumentError)
      end

      it 'delegates to SemiSemantic::Version' do
        expect(SemiSemantic::Version).to receive(:parse).with('1.0.1').and_call_original

        described_class.parse('1.0.1')
      end

      it 'stringifies objects before parsing' do
        model = double(:fake_version, to_s: '1.0.1')
        expect(described_class.parse(model).to_s).to eq('1.0.1')
      end

      it 'ignores anything after a space' do
        expect(described_class.parse('12.1 (some information)').to_s).to eq('12.1')
      end

      context 'with an invalid version' do
        let(:invalid_version_string) { '&' }

        it 'raises a Bosh::Common::Version::ParseError' do
          expect { described_class.parse(invalid_version_string) }.to raise_error(Bosh::Common::Version::ParseError)
        end
      end
    end

    describe '#default_post_release' do
      let(:a) { described_class.parse('1.0.1') }

      it 'fails' do
        expect{a.default_post_release}.to raise_error(NotImplementedError)
      end
    end

    describe 'parse_and_compare' do
      describe 'version numbers that have spaces' do
        it 'orders the versions before the space in numerical order' do
          expect(described_class.parse_and_compare('1741 (bosh:87h1rn71t cli:2398562385h)', '1741')).to eq(0)
          expect(described_class.parse_and_compare('1.2448.0 (release:c436f47b bosh:c436f47b)', '1.2500')).to eq(-1)
          expect(described_class.parse_and_compare('1.1.1 (bosh:87h1rn71t cli:2398562385h)', '1.1.0')).to eq(1)
        end
      end
    end
  end
end
