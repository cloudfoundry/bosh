require 'spec_helper'

module Bosh::Cli::Versions
  describe ReleaseVersionsIndex do
    let(:version_index) { instance_double('Bosh::Cli::Versions::VersionsIndex') }
    let(:release_versions_index) { ReleaseVersionsIndex.new(version_index) }

    describe '#versions' do
      it 'exposes the version strings as a ReleaseVersionList' do
        version_strings = ['1.8-dev', '1.9-dev']
        allow(version_index).to receive(:version_strings).and_return(version_strings)

        expected_version_list = Bosh::Common::Version::ReleaseVersionList.parse(version_strings)
        expect(release_versions_index.versions).to eq(expected_version_list)
      end
    end

    describe '#latest_version' do
      it 'returns the maximum version' do
        version_strings = ['7', '8', '9', '8.1', '9-alpha.1']
        allow(version_index).to receive(:version_strings).and_return(version_strings)

        expect(release_versions_index.latest_version.to_s).to eq('9')
      end
    end
  end
end
