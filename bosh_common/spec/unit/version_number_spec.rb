# coding: UTF-8

require 'common/version_number'

describe Bosh::Common::VersionNumber do
  describe '.parse' do
    it 'converts a dev component into a post-release segment' do
      expect(described_class.parse('1.2.0')).to eq(SemiSemantic::Version.parse('1.2.0'))
      expect(described_class.parse('1.2.0-dev')).to eq(SemiSemantic::Version.parse('1.2+dev.0'))
      expect(described_class.parse('1.2+dev.0')).to eq(SemiSemantic::Version.parse('1.2+dev.0'))
      expect(described_class.parse('1.2-dev')).to eq(SemiSemantic::Version.parse('1+dev.2'))
      expect(described_class.parse('1.2-dev.1')).to eq(SemiSemantic::Version.parse('1.2-dev.1'))
    end

    it 'converts underscores to periods' do
      expect(described_class.parse('12_1')).to eq(SemiSemantic::Version.parse('12.1'))
      expect(described_class.parse('1.2_2-alpha_1')).to eq(SemiSemantic::Version.parse('1.2.2-alpha.1'))
    end

    it 'ignores anything after a space' do
      expect(described_class.parse('12.1 (some information)')).to eq(SemiSemantic::Version.parse('12.1'))
    end

    it 'raises an error when the version string is invalid' do
      semi_semantic_version = class_double('SemiSemantic::Version').as_stubbed_const
      allow(semi_semantic_version).to receive(:parse).and_raise(ArgumentError)
      expect { described_class.parse('') }.to raise_error(ArgumentError)
    end
  end
end
