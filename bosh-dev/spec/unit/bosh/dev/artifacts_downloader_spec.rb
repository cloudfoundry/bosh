require 'spec_helper'
require 'bosh/dev/build'
require 'bosh/dev/download_adapter'
require 'bosh/dev/artifacts_downloader'
require 'bosh/stemcell/stemcell'

module Bosh::Dev
  describe ArtifactsDownloader do
    subject(:artifacts_downloader) { ArtifactsDownloader.new(download_adapter, logger) }
    let(:download_adapter) { DownloadAdapter.new(logger) }

    describe '#download_release' do
      it 'downloads a release and returns path' do
        expected_remote_uri = URI('http://bosh-ci-pipeline.s3.amazonaws.com/fake-build-number/release/bosh-fake-build-number.tgz')
        expected_local_path = 'fake-output-dir/bosh-fake-build-number.tgz'

        expect(download_adapter)
          .to receive(:download)
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
        )
      end

      let(:infrastructure) do
        instance_double(
          'Bosh::Stemcell::Infrastructure::Base',
          name: 'fake-infrastructure-name',
          default_disk_format: 'default-disk-format'
        )
      end

      let(:definition) {
        instance_double(
          'Bosh::Stemcell::Definition',
          infrastructure: infrastructure,
          light?: true,
          stemcell_name: 'fake-stemcell-name-fake-disk-format'
        )
      }

      let(:stemcell) { Bosh::Stemcell::Stemcell.new(definition, 'bosh-stemcell', 'fake-build-number', 'fake-disk-format')}

      it 'downloads a stemcell and returns path' do
        expected_remote_uri = URI('http://bosh-ci-pipeline.s3.amazonaws.com/fake-build-number/bosh-stemcell/fake-infrastructure-name/light-bosh-stemcell-fake-build-number-fake-stemcell-name-fake-disk-format.tgz')
        expected_local_path = "fake-output-dir/#{stemcell.name}"

        expect(download_adapter)
          .to receive(:download)
          .with(expected_remote_uri, expected_local_path)
          .and_return('returned-path')

        returned_path = artifacts_downloader.download_stemcell(stemcell, 'fake-output-dir')

        expect(returned_path).to eq('returned-path')
      end
    end
  end
end
