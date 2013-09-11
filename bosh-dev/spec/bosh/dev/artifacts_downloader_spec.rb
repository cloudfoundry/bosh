require 'spec_helper'
require 'bosh/dev/artifacts_downloader'

module Bosh
  module Dev
    describe ArtifactsDownloader do
      let(:fake_download_adapter) { DownloadAdapter.new }
      subject(:artifacts_downloader) { ArtifactsDownloader.new }
      before { DownloadAdapter.stub(new: fake_download_adapter) }

      describe '#download_release' do
        it 'downloads a release and returns path' do
          fake_download_adapter.
              should_receive(:download).
              with('https://s3.amazonaws.com/bosh-jenkins-artifacts/release/bosh-123.tgz', 'bosh-123.tgz').
              and_return(File.join(Dir.pwd, 'where-it-was-written-to'))
          expect(artifacts_downloader.download_release('123')).to eq File.join(Dir.pwd, 'where-it-was-written-to')
        end
      end

      describe '#download_stemcell' do
        it 'downloads a stemcell and returns path' do
          fake_download_adapter.
              should_receive(:download).
              with('https://s3.amazonaws.com/bosh-jenkins-artifacts/bosh-stemcell/aws/light-bosh-stemcell-123-aws-xen-ubuntu.tgz',
                   'light-bosh-stemcell-123-aws-xen-ubuntu.tgz').
              and_return(File.join(Dir.pwd, 'where-it-was-written-to'))
          expect(artifacts_downloader.download_stemcell('123')).to eq File.join(Dir.pwd, 'where-it-was-written-to')
        end
      end
    end
  end
end
