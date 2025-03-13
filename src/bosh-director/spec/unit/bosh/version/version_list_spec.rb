require 'spec_helper'

module Bosh::Version
  describe VersionList do
    subject(:version_list) { described_class.parse(versions, SemiSemanticVersion) }

    describe '#parse' do
      it 'creates a new object' do
        expect(described_class.parse([], SemiSemanticVersion)).to be_instance_of(described_class)
      end

      it 'raises an error if the supplied version_type does not have a parse method' do
        expect {
          described_class.parse([], String)
        }.to raise_error(TypeError)
      end
    end

    describe '#latest_with_pre_release' do
      let(:versions) { ['1.0.1+dev.1', '0.0.5', '1.0.1', '1.0.1-alpha.1', '1.0.1-alpha.1+dev.2'] }

      it 'returns the maximum version with the same release and pre-release segments' do
        version = SemiSemanticVersion.parse('1.0.1-alpha.1')
        expect(version_list.latest_with_pre_release(version).to_s).to eq('1.0.1-alpha.1+dev.2')
      end

      it 'supports versions without pre-release' do
        version = SemiSemanticVersion.parse('1.0.1')
        expect(version_list.latest_with_pre_release(version).to_s).to eq('1.0.1+dev.1')
      end

      it 'ignores supplied post-release' do
        version = SemiSemanticVersion.parse('1.0.1-alpha.1+dev.100')
        expect(version_list.latest_with_pre_release(version).to_s).to eq('1.0.1-alpha.1+dev.2')
      end
    end

    describe '#latest_with_release' do
      let(:versions) { ['1.0.1+dev.1', '0.0.5', '1.0.1', '1.0.1-alpha.1', '1.0.1-alpha.1+dev.2'] }

      it 'returns the maximum version with the same release' do
        version = SemiSemanticVersion.parse('1.0.1-alpha.1')
        expect(version_list.latest_with_release(version).to_s).to eq('1.0.1+dev.1')
      end

      it 'supports versions without pre-release or post-release' do
        version = SemiSemanticVersion.parse('1.0.1')
        expect(version_list.latest_with_release(version).to_s).to eq('1.0.1+dev.1')
      end

      it 'ignores supplied pre-release and post-release' do
        version = SemiSemanticVersion.parse('1.0.1-alpha.1+dev.100')
        expect(version_list.latest_with_release(version).to_s).to eq('1.0.1+dev.1')
      end
    end

    describe '#sort' do
      let(:versions) { ['1.0.1+dev.1', '0.0.5', '1.0.1', '1.0.1-alpha.1', '1.0.1-alpha.1+dev.2'] }
      let(:asc_versions) { ['0.0.5', '1.0.1-alpha.1', '1.0.1-alpha.1+dev.2', '1.0.1', '1.0.1+dev.1'] }

      it 'returns a new Array of versions sorted in ascending order' do
        expect(version_list.sort.map(&:to_s)).to eq(asc_versions)
      end
    end

    describe '#max' do
      let(:versions) { ['1.0.1+dev.1', '0.0.5', '1.0.1'] }

      it 'returns the maximum of the versions in the list' do
        expect(version_list.max.to_s).to eq('1.0.1+dev.1')
      end
    end

    describe 'equals' do
      let(:versions) { ['1.0.0', '1.0.1', '1.1.0'] }

      it 'supports equality comparison' do
        expect(version_list).to eq(VersionList.parse(versions, SemiSemanticVersion))
        expect(version_list).to_not eq(VersionList.parse(versions.concat(['1.2.0']), SemiSemanticVersion))
      end
    end

    describe '#to_s' do
      let(:versions) { ['1.0.0', '1.0.1', '1.1.0'] }

      it 'returns a string representation' do
        expect(version_list.to_s).to eq(versions.to_s)
      end
    end
  end
end
