require 'spec_helper'
require 'cli/download_with_progress'

module Bosh::Cli
  describe DownloadWithProgress do
    let(:url) { 'http://example.com/foo/bar.tgz' }
    let(:size) { 1234 }

    subject(:download_with_progress) do
      DownloadWithProgress.new(url, size)
    end

    describe '#perform' do
      let(:size) { 1234 }
      let(:chunk) { double('chunk', size: 'chunk-size') }
      let(:file) { instance_double('File', write: nil) }
      let(:http_client) { instance_double('HTTPClient') }
      let(:progess_bar) do
        instance_double('ProgressBar',
                        file_transfer_mode: nil,
                        write: nil,
                        inc: nil,
                        finish: nil)
      end

      before do
        ProgressBar.stub(:new).and_return(progess_bar)
        HTTPClient.stub(:new).and_return(http_client)
        http_client.stub(:get).and_yield(chunk)
        File.stub(:open).and_yield(file)
      end

      it 'downloads the file from the specified url' do
        download_with_progress.perform

        expect(http_client).to have_received(:get).with(url)
        expect(file).to have_received(:write).with(chunk)
      end

      it 'downloads the file to the current directory' do
        download_with_progress.perform

        expect(File).to have_received(:open).with('bar.tgz', 'w')
      end

      it 'reports progress along the way' do
        download_with_progress.perform

        expect(progess_bar).to have_received(:file_transfer_mode)
        expect(progess_bar).to have_received(:inc).with('chunk-size')
        expect(progess_bar).to have_received(:finish)
      end
    end

    describe '#sha1?' do
      subject do
        download_with_progress.sha1?(expected_sha1)
      end

      let(:sha1_digest) { instance_double('Digest::SHA1', hexdigest: 'bar-sha1') }

      before do
        Digest::SHA1.stub(:file).with('bar.tgz').and_return(sha1_digest)
      end

      context 'when the sha1 matches the downloaded file' do
        let(:expected_sha1) { 'bar-sha1' }

        it { should be(true) }
      end

      context 'when the sha1 does not match the downloaded file' do
        let(:expected_sha1) { 'baaaar-sha1' }

        it { should be(false) }
      end
    end
  end
end
