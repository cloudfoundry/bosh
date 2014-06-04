require 'common/version/stemcell_version'

module Bosh::Common::Version
  describe StemcellVersion do

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

      it 'converts underscores to periods' do
        expect(described_class.parse('12_1').to_s).to eq('12.1')
        expect(described_class.parse('1.2_2-alpha_1').to_s).to eq('1.2.2-alpha.1')
      end
    end

    describe '#default_post_release' do
      let(:a) { described_class.parse('1.0.1') }

      it 'fails' do
        expect{a.default_post_release}.to raise_error(NotImplementedError)
      end
    end

    describe 'parse_and_compare' do
      describe 'version numbers with a date (YYYY-MM-DD_hh-mm-ss) suffix' do
        it 'correctly orders them based on their version number and post-release date' do
          expect(described_class.parse_and_compare('10.0.at-2013-02-27_21-38-27', '2.0.at-2013-02-26_01-26-46')).to eq(1)
          expect(described_class.parse_and_compare('2.0.at-2013-02-27_21-38-27', '10.0.at-2013-02-26_01-26-46')).to eq(-1)
          expect(described_class.parse_and_compare('2.0.at-2013-02-27_21-38-27', '2.0.at-2013-02-27_21-38-27')).to eq(0)
        end
      end

      describe 'version numbers that are dates (YYYY-MM-DD_hh-mm-ss)' do
        it 'orders them in chronological order' do
          expect(described_class.parse_and_compare('2013-02-26_01-26-46', '2013-02-26_01-26-46')).to eq(0)
          expect(described_class.parse_and_compare('2013-02-26_01-26-46', '2013-02-27_21-38-27')).to eq(-1)
          expect(described_class.parse_and_compare('2013-02-27_21-38-27', '2013-02-26_01-26-46')).to eq(1)
        end
      end

      describe 'version numbers that use underscores as separators' do
        it 'orders them in numerical order' do
          expect(described_class.parse_and_compare('1741', '1741_0')).to eq(0)
          expect(described_class.parse_and_compare('1741_0', '1741_1')).to eq(-1)
          expect(described_class.parse_and_compare('1741_2', '1741_1')).to eq(1)
        end
      end
    end

  end
end
