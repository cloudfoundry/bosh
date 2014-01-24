require 'logger'
require 'spec_helper'
require 'bosh/dev/build'
require 'bosh/dev/build_target'
require 'bosh/dev/download_adapter'
require 'bosh/dev/artifacts_downloader'

module Bosh::Dev
  describe ArtifactsDownloader do
    subject(:artifacts_downloader) { ArtifactsDownloader.new(download_adapter, logger) }
    let(:download_adapter) { DownloadAdapter.new(logger) }
    let(:logger) { Logger.new('/dev/null') }

    describe '#download_release' do
      it 'downloads a release and returns path' do
        expected_remote_uri = URI('http://bosh-jenkins-artifacts.s3.amazonaws.com/release/bosh-fake-build-number.tgz')
        expected_local_path = 'fake-output-dir/bosh-fake-build-number.tgz'

        download_adapter
          .should_receive(:download)
          .with(expected_remote_uri, expected_local_path)
          .and_return('returned-path')

        returned_path = artifacts_downloader.download_release('fake-build-number', 'fake-output-dir')
        expect(returned_path).to eq('returned-path')
      end
    end

    describe '#download_stemcell' do
      let(:build_target) do
        instance_double(
          'Bosh::Dev::BuildTarget',
          build_number: 'fake-build-number',
          definition: definition,
          infrastructure: infrastructure,
          infrastructure_light?: true,
        )
      end

      let(:infrastructure) do
        instance_double(
          'Bosh::Stemcell::Infrastructure::Base',
          name: 'fake-infrastructure-name',
        )
      end

      let(:definition) {
        instance_double(
          'Bosh::Stemcell::Definition',
          infrastructure: infrastructure,
        )
      }

      let(:archive_filename) {
        instance_double('Bosh::Stemcell::ArchiveFilename', to_s: 'fake-stemcell-filename')
      }

      before do
        allow(Bosh::Stemcell::ArchiveFilename).to receive(:new).and_return(archive_filename)
      end

      it 'downloads a stemcell and returns path' do
        expected_remote_uri = URI("http://bosh-jenkins-artifacts.s3.amazonaws.com/bosh-stemcell/fake-infrastructure-name/#{archive_filename}")
        expected_local_path = "fake-output-dir/#{archive_filename}"

        download_adapter
          .should_receive(:download)
          .with(expected_remote_uri, expected_local_path)
          .and_return('returned-path')

        returned_path = artifacts_downloader.download_stemcell(build_target, 'fake-output-dir')

        expect(Bosh::Stemcell::ArchiveFilename).to have_received(:new)
                                                   .with('fake-build-number', definition, 'bosh-stemcell', true)
        expect(returned_path).to eq('returned-path')
      end
    end
  end
end
