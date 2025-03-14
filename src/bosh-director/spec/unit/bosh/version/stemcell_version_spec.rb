require 'spec_helper'

module Bosh::Version
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

      context 'with an invalid version' do
        let(:invalid_version_string) { '&' }

        it 'raises a Bosh::Version::ParseError' do
          expect { described_class.parse(invalid_version_string) }.to raise_error(Bosh::Version::ParseError)
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
          expect(described_class.parse_and_compare('1741', '1741.0')).to eq(0)
          expect(described_class.parse_and_compare('1741.0', '1741.1')).to eq(-1)
          expect(described_class.parse_and_compare('1741.2', '1741.1')).to eq(1)
        end
      end
    end

    describe '#matches' do
      context 'using the static helper method' do
        it 'calls the instance method' do
          fake_version_a = instance_double(described_class)
          expect(described_class).to receive(:parse).with('1.0').and_return(fake_version_a)

          fake_version_b = instance_double(described_class)
          expect(described_class).to receive(:parse).with('1.1').and_return(fake_version_b)

          expect(fake_version_a).to receive(:matches).with(fake_version_b)
          described_class.match('1.0', '1.1')
        end
      end

      context 'when stemcell uses semi-semantic versioning' do
        it 'matches the same version' do
          version = described_class.parse('1')
          same = described_class.parse('1')
          expect(version.matches(same)).to be(true)
        end

        it 'matches a newer patch' do
          version = described_class.parse('1')
          newer_patch = described_class.parse('1.1')
          expect(version.matches(newer_patch)).to be(true)
        end

        it 'matches an older patch' do
          version = described_class.parse('1.2')
          older_patch = described_class.parse('1.1')
          expect(version.matches(older_patch)).to be(true)
        end

        it 'does not match a newer version' do
          version = described_class.parse('1')
          newer_version = described_class.parse('2')
          expect(version.matches(newer_version)).to be(false)
        end

        it 'does not match an older version' do
          version = described_class.parse('2')
          older_version = described_class.parse('1')
          expect(version.matches(older_version)).to be(false)
        end

        it 'ignores all non-release segments' do
          version = described_class.parse('1.0')
          version_with_pre_release = described_class.parse('1.0-alpha.1')
          version_with_post_release = described_class.parse('1.0+build.1')
          expect(version.matches(version_with_pre_release)).to be(true)
          expect(version.matches(version_with_post_release)).to be(true)
          expect(version_with_pre_release.matches(version_with_post_release)).to be(true)
        end
      end

      context 'when stemcell uses semantic versioning' do
        let(:version) do
          described_class.parse('1.1.1')
        end

        it 'matches the same version' do
          newer_patch = described_class.parse('1.1.1')
          expect(version.matches(newer_patch)).to be(true)
        end

        context 'comparing to other patch versions' do
          it 'matches a newer patch version' do
            newer_patch = described_class.parse('1.1.2')
            expect(version.matches(newer_patch)).to be(true)
          end

          it 'matches an older patch version' do
            older_patch = described_class.parse('1.1.0')
            expect(version.matches(older_patch)).to be(true)
          end
        end

        context 'comparing to other minor versions' do
          it 'matches a newer minor version' do
            newer_minor_version = described_class.parse('1.2.0')
            expect(version.matches(newer_minor_version)).to be(true)
          end

          it 'matches an older minor version' do
            older_minor_version = described_class.parse('1.0.9')
            expect(version.matches(older_minor_version)).to be(true)
          end
        end

        context 'comparing to other major versions' do
          it 'does not match a newer major version' do
            newer_major_version = described_class.parse('2.0.0')
            expect(version.matches(newer_major_version)).to be(false)
          end

          it 'does not match an older major version' do
            older_major_version = described_class.parse('0.9.9')
            expect(version.matches(older_major_version)).to be(false)
          end
        end
      end
    end
  end
end
