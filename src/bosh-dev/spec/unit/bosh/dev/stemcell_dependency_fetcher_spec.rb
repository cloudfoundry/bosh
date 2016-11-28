require 'spec_helper'
require 'bosh/dev/stemcell_dependency_fetcher'
require 'bosh/dev/download_adapter'

module Bosh::Dev
  describe StemcellDependencyFetcher do
    include FakeFS::SpecHelpers

    subject { described_class.new(downloader, logger) }

    let(:downloader) { instance_double(Bosh::Dev::DownloadAdapter) }

    describe '#download_os_image' do
      let(:os_image_json) { '{ "bosh-fake-image.tgz": "FAKE_VERSION_KEY" }' }

      before do
        os_image_versions_file = File.expand_path('../../../../../../bosh-stemcell/os_image_versions.json', __FILE__)
        FileUtils.mkdir_p(File.dirname(os_image_versions_file))
        File.open(os_image_versions_file, 'w') do |f|
          f.puts(os_image_json)
        end
      end

      it 'downloads the version specified in os_image_versions.json' do
        expected_uri = URI('https://s3.amazonaws.com/my-fake-bucket/bosh-fake-image.tgz?versionId=FAKE_VERSION_KEY')
        output_path = 'fake-path'
        expect(downloader).to receive(:download).with(expected_uri, output_path)
        subject.download_os_image(bucket_name: 'my-fake-bucket', key: 'bosh-fake-image.tgz', output_path: output_path)
      end

      context 'when key is not present in JSON file' do
        it 'raises an error' do
          expect {
            subject.download_os_image(bucket_name: 'my-fake-bucket', key: 'missing-key', output_path: 'fake-path')
          }.to raise_error(/missing-key/)
        end
      end
    end
  end
end
