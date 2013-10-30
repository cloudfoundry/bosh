require 'spec_helper'
require 'bosh/director/compiled_packages_exporter'

module Bosh::Director
  describe CompiledPackagesExporter do
    describe '#export' do
      let(:archiver) { double('gzipper') }
      let(:downloader) { double('compiled package downloader', cleanup: nil) }
      let(:blobstore_client) { double('blobstore client') }
      let(:group) { double('compiled package group') }

      before do
        CompiledPackageDownloader.stub(:new).with(group, blobstore_client).and_return(downloader)
        TarGzipper.stub(new: archiver)
      end

      it 'downloads the compiled packages from blobstore using CompiledPackageDownloader and creates a gzipped tar using TarGzipper' do
        download_dir = '/path/to/download_dir'

        downloader.should_receive(:download).with(no_args).and_return(download_dir)
        output_path = '/path/to/output.tar.gz'

        archiver.should_receive(:compress).with(download_dir, 'compiled_packages', output_path)
        exporter = CompiledPackagesExporter.new(group, blobstore_client)
        exporter.export(output_path)
      end

      it 'cleans up the downloaded artifacts using the downloader' do
        downloader.stub(:download)

        archiver.stub(compress: nil)

        output_path = '/path/to/output.tar.gz'
        downloader.should_receive(:cleanup).with(no_args)
        exporter = CompiledPackagesExporter.new(group, blobstore_client)
        exporter.export(output_path)
      end
    end
  end
end
