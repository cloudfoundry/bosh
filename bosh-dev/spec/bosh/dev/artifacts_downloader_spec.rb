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
          infrastructure: infrastructure,
          operating_system: operating_system,
          infrastructure_light?: true,
        )
      end

      let(:infrastructure) do
        instance_double(
          'Bosh::Stemcell::Infrastructure::Base',
          name: 'fake-infrastructure-name',
          hypervisor: 'fake-infrastructure-hypervisor',
        )
      end

      let(:operating_system) do
        instance_double(
          'Bosh::Stemcell::OperatingSystem::Base',
          name: 'fake-os-name',
        )
      end

      it 'downloads a stemcell and returns path' do
        expected_name = [
          'light',
          'bosh-stemcell',
          'fake-build-number',
          'fake-infrastructure-name',
          'fake-infrastructure-hypervisor',
          'fake-os-name.tgz',
        ].join('-')

        expected_remote_uri = URI("http://bosh-jenkins-artifacts.s3.amazonaws.com/bosh-stemcell/fake-infrastructure-name/#{expected_name}")
        expected_local_path = "fake-output-dir/#{expected_name}"

        download_adapter
          .should_receive(:download)
          .with(expected_remote_uri, expected_local_path)
          .and_return('returned-path')

        returned_path = artifacts_downloader.download_stemcell(build_target, 'fake-output-dir')
        expect(returned_path).to eq('returned-path')
      end
    end
  end
end
