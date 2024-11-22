require 'spec_helper'

module Bosh::Common::Version
  describe ReleaseVersionList do
    let(:version_list) { described_class.parse(versions) }

    def parse(version)
      ReleaseVersion.parse(version)
    end

    describe '#parse' do
      let(:versions) { ['1.0.1', '10.9-dev'] }

      it 'creates a new object' do
        expect(described_class.parse(versions)).to be_instance_of(described_class)
      end

      it 'delegates to VersionList' do
        expect(VersionList).to receive(:parse).with(versions, ReleaseVersion).and_call_original

        described_class.parse(versions)
      end
    end

    describe '#rebase' do
      let(:versions) { [] }

      it 'fails to rebase final versions' do
        expect{version_list.rebase(parse('9.1'))}.to raise_error(ArgumentError)
        expect{version_list.rebase(parse('9.1-RC.1'))}.to raise_error(ArgumentError)
      end

      context 'when there are no versions in the list' do
        it 'uses the provided release and pre-release with the default dev post-release segment' do
          expect(version_list.rebase(parse('10.9-dev'))).to eq parse('10.1-dev')
          expect(version_list.rebase(parse('8.5-dev'))).to eq parse('8.1-dev')

          expect(version_list.rebase(parse('1.0.0-RC.1+dev.10'))).to eq parse('1.0.0-RC.1+dev.1')
        end
      end

      context 'when the server has a version that matches the release and pre-release segments with no post-release segment' do
        let(:versions) { ['9.1'] }

        it 'uses the provided release and pre-release with a new dev post-release segment' do
          expect(version_list.rebase(parse('9+dev.9'))).to eq parse('9+dev.1')
        end
      end

      context 'when the server has a version that matches the release and pre-release segments and any post-release segment' do
        let(:versions) { ['9.1', '9.1.1-dev'] }

        it 'increments the latest post-release segment with the same release and pre-release segments' do
          expect(version_list.rebase(parse('9.1.8-dev'))).to eq parse('9.1.2-dev')
        end
      end

      context 'when the server does not have a version that matches the release and post-release segments' do
        let(:versions) { ['9.1', '9.1.1-dev'] }

        it 'uses the provided release and pre-release with a new dev post-release segment' do
          expect(version_list.rebase(parse('8.9-dev'))).to eq parse('8.1-dev')
          expect(version_list.rebase(parse('9.2.9-dev'))).to eq parse('9.2.1-dev')
        end
      end

      context 'when there are multiple final versions on the server' do
        let(:versions) { ['9.1', '9.2'] }

        it 'supports rebasing onto older final versions' do
          expect(version_list.rebase(parse('9.1.5-dev'))).to eq parse('9.1.1-dev')
        end
      end
    end

    describe 'equals' do
      let(:versions) { ['1.0.0', '1.0.1', '1.1.0'] }

      it 'supports equality comparison' do
        expect(version_list).to eq(ReleaseVersionList.parse(versions))
      end

      it 'supports equality comparison with VersionList' do
        expect(version_list).to eq(VersionList.parse(versions, ReleaseVersion))
      end
    end
  end
end
