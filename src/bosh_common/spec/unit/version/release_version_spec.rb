require 'spec_helper'

module Bosh::Common::Version
  describe ReleaseVersion do

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

      it 'converts a "#-dev" suffix into a "+dev.#" post-release segment' do
        expect(described_class.parse('1.2.0').to_s).to eq('1.2.0')
        expect(described_class.parse('1.2.0-dev').to_s).to eq('1.2+dev.0')
        expect(described_class.parse('1.2+dev.0').to_s).to eq('1.2+dev.0')
        expect(described_class.parse('1.2-dev').to_s).to eq('1+dev.2')
        expect(described_class.parse('1.2-dev.1').to_s).to eq('1.2-dev.1')
      end

      context 'with an invalid version' do
        let(:invalid_version_string) { '&' }

        it 'raises a Bosh::Common::Version::ParseError' do
          expect { described_class.parse(invalid_version_string) }.to raise_error(Bosh::Common::Version::ParseError)
        end
      end
    end

    describe 'to_old_format' do
      subject { described_class.parse(version) }

      context 'when the format supplied can be converted to the old-format' do
        let(:version) { '1.2+dev.0' }

        it 'returns the version in the old format' do
          expect(subject.to_old_format).to eq('1.2.0-dev')
        end
      end

      context 'when the format supplied cannot be converted to the old-format' do
        let(:version) { '1.2.0-alpha.1+build.1.0' }

        it 'returns nil' do
          expect(subject.to_old_format).to be_nil
        end
      end
    end

    describe '#default_post_release' do
      let(:a) { described_class.parse('1.0.1') }
      let(:b) { described_class.parse('1.0.2+dev.10') }

      it 'creates a new version object with the post-release segement set to the default value' do
        expect(a.default_post_release).to eq described_class.parse('1.0.1+dev.1')
        expect(b.default_post_release).to eq described_class.parse('1.0.2+dev.1')
      end

      it 'allows chaining' do
        expect(described_class.parse('1.0.1').
          default_post_release.
          version.post_release.
          components[0]).to eq 'dev'
      end

      it 'returns a new object and does not change the old one' do
        c = a.default_post_release
        expect(c).to_not be(a)
        expect(c.to_s).to_not eq(a.to_s)
        expect(a.to_s).to eq('1.0.1')
      end
    end

    describe 'parse_and_compare' do
      describe 'version numbers with -dev suffix' do
        it 'correctly orders them' do
          expect(described_class.parse_and_compare('10.9-dev', '10.10-dev')).to eq(-1)
          expect(described_class.parse_and_compare('10.10-dev', '10.10-dev')).to eq(0)
          expect(described_class.parse_and_compare('0.2.3-dev', '0.2.3.0.3-dev')).to eq(-1)
          expect(described_class.parse_and_compare('10.10-dev', '10.9-dev')).to eq(1)
        end

        it '-dev is treated as a post-release, greater than the release version' do
          expect(described_class.parse_and_compare('10', '10.10-dev')).to eq(-1)
          expect(described_class.parse_and_compare('10.1.2.10-dev', '10.1.2')).to eq(1)
        end
      end
    end

  end
end
