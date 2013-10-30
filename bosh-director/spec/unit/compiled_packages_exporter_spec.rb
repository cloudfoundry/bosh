require 'spec_helper'
require 'bosh/director/compiled_packages_exporter'

module Bosh::Director
  describe CompiledPackagesExporter do
    describe '#tgz_path' do
      let(:archiver) { double('gzipper') }
      let(:output_dir) { '/path/to/output_dir' }
      let(:downloader) { double('compiled package downloader', cleanup: nil) }
      let(:blobstore_client) { double('blobstore client') }
      let(:group) { double('compiled package group') }

      before do
        CompiledPackageDownloader.stub(:new).with(group, blobstore_client).and_return(downloader)
        TarGzipper.stub(new: archiver)
      end
      subject(:exporter) { CompiledPackagesExporter.new(group, blobstore_client, output_dir) }

      it 'downloads the compiled packages from blobstore using CompiledPackageDownloader and creates a gzipped tar using DirGzipper' do
        download_dir = '/path/to/download_dir'


        downloader.should_receive(:download).with(no_args).and_return(download_dir)
        archiver.should_receive(:compress).with(download_dir, 'compiled_packages', File.join(output_dir, 'compiled_packages.tgz'))
        expect(exporter.tgz_path).to eq(File.join(output_dir, 'compiled_packages.tgz'))
      end

      it 'cleans up the downloaded artifacts using the downloader' do
        downloader.stub(:download)

        archiver.stub(compress: nil)

        downloader.should_receive(:cleanup).with(no_args)
        exporter.tgz_path
      end
    end
  end
end
