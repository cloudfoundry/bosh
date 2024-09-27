require 'common/version/semi_semantic_version'

module Bosh::Common::Version
  describe SemiSemanticVersion do

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

      context 'with an invalid version' do
        let(:invalid_version_string) { '&' }

        it 'raises a Bosh::Common::Version::ParseError' do
          expect { described_class.parse(invalid_version_string) }.to raise_error(Bosh::Common::Version::ParseError)
        end
      end
    end

    describe 'described_class.parse_and_compare' do
      let(:a) { described_class.parse('1.0.1') }
      let(:b) { described_class.parse('1.0.2+dev.10') }

      it 'compares strings as SemiSemantic versions' do
        expect(described_class.parse_and_compare(a, b)).to eq(-1)
        expect(described_class.parse_and_compare(b, a)).to eq(1)
        expect(described_class.parse_and_compare(a, a)).to eq(0)
      end
    end

    describe '#default_post_release' do
      let(:a) { described_class.parse('1.0.1') }
      let(:b) { described_class.parse('1.0.2+dev.10') }

      it 'creates a new version object with the post-release segement set to the default value' do
        expect(a.default_post_release).to eq described_class.parse('1.0.1+build.1')
        expect(b.default_post_release).to eq described_class.parse('1.0.2+build.1')
      end

      it 'allows chaining' do
        expect(described_class.parse('1.0.1').
          default_post_release.
          version.post_release.
          components[0]).to eq 'build'
      end

      it 'returns a new object and does not change the old one' do
        c = a.default_post_release
        expect(c).to_not be(a)
        expect(c.to_s).to_not eq(a.to_s)
        expect(a.to_s).to eq('1.0.1')
      end
    end

    describe '#increment_post_release' do
      let(:a) { described_class.parse('1.0.1') }
      let(:b) { described_class.parse('1.0.2+dev.10') }

      it 'fails when post-release is nil' do
        expect{a.increment_post_release}.to raise_error(Bosh::Common::Version::UnavailableMethodError)
      end

      it 'creates a new version object with the post-release segment incremented by 1' do
        expect(b.increment_post_release).to eq described_class.parse('1.0.2+dev.11')
      end

      it 'allows chaining' do
        expect(described_class.parse('1.0.1+dev.11').
          increment_post_release.
          version.post_release.
          components[0]).to eq 'dev'
      end

      it 'returns a new object and does not change the old one' do
        c = b.increment_post_release
        expect(c).to_not be(b)
        expect(c.to_s).to_not eq(b.to_s)
        expect(b.to_s).to eq('1.0.2+dev.10')
      end
    end

    describe 'increment_release' do
      let(:a) { described_class.parse('1.0.1') }

      it 'creates a new version object with the release segment incremented by 1' do
        expect(a.increment_release).to eq described_class.parse('1.0.2')
      end

      it 'allows chaining' do
        expect(described_class.parse('1.0.1+dev.11').
          increment_release.
          version.release.
          components[0]).to eq 1
      end

      it 'returns a new object and does not change the old one' do
        c = a.increment_release
        expect(c).to_not be(a)
        expect(c.to_s).to_not eq(a.to_s)
        expect(a.to_s).to eq('1.0.1')
      end
    end

    describe '#<=>' do
      let(:a) { described_class.parse('1.0.1') }
      let(:a2) { described_class.parse('1.0.1') }
      let(:b) { described_class.parse('1.0.2') }

      it 'compares two versions' do
        expect(a).to be < b
        expect(b).to be > a
        expect(a).to eq a2
      end
    end

    describe '#to_s' do
      let(:a) { described_class.parse('1.0.1') }

      it 'returns the string value' do
        expect(a.to_s).to eq '1.0.1'
      end
    end

    describe 'parse_and_compare' do
      describe 'only major version numbers' do
        context 'when version are strings' do
          it 'casts to and compares as integers' do
            expect(described_class.parse_and_compare('10', '9')).to eq(1)
            expect(described_class.parse_and_compare('009', '10')).to eq(-1)
            expect(described_class.parse_and_compare('10', '10')).to eq(0)
          end
        end

        context 'when versions are integers' do
          it 'compares' do
            expect(described_class.parse_and_compare(10, 11)).to eq(-1)
            expect(described_class.parse_and_compare(43, 42)).to eq(1)
            expect(described_class.parse_and_compare(7, 7)).to eq(0)
          end
        end
      end

      describe 'major.minor version numbers' do
        it 'compares each component as integers' do
          expect(described_class.parse_and_compare('1.2', '1.3')).to eq(-1)
          expect(described_class.parse_and_compare('1.2', '1.2')).to eq(0)
          expect(described_class.parse_and_compare('1.3', '1.2')).to eq(1)
        end
      end

      describe 'major.minor.patch.and.beyond version numbers' do
        it 'compares each component as integers' do
          expect(described_class.parse_and_compare('0.1.7', '0.1.7')).to eq(0)
          expect(described_class.parse_and_compare('0.1.7', '0.1.7.0')).to eq(0)
          expect(described_class.parse_and_compare('0.2.3', '0.2.3.0.8')).to eq(-1)
          expect(described_class.parse_and_compare('0.1.7', '0.9.2')).to eq(-1)
          expect(described_class.parse_and_compare('0.1.7.5', '0.1.7')).to eq(1)
          expect(described_class.parse_and_compare('0.1.7.4.9.9', '0.1.7.5')).to eq(-1)
        end
      end
    end
  end
end
