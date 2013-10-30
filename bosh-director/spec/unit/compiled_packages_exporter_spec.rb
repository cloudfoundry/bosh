require 'spec_helper'
require 'bosh/director/compiled_packages_exporter'

module Bosh::Director
  describe CompiledPackagesExporter do
    describe '#tgz_path' do
      it 'downloads the compiled packages from blobstore using CompiledPackageDownloader and creates a gzipped tar using DirGzipper' do
        group = double('compiled package group')
        download_dir = '/path/to/download_dir'

        downloader = double('compiled package downloader')
        blobstore_client = double('blobstore client')
        CompiledPackageDownloader.stub(:new).with(group, blobstore_client).and_return(downloader)

        output_dir = '/path/to/output_dir'
        archiver = double('gzipper')
        TarGzipper.stub(:new).and_return(archiver)

        exporter = CompiledPackagesExporter.new(group, blobstore_client, output_dir)

        downloader.should_receive(:download).with(no_args).and_return(download_dir)
        archiver.should_receive(:compress).with(download_dir, 'compiled_packages', File.join(output_dir, 'compiled_packages.tgz'))
        expect(exporter.tgz_path).to eq(File.join(output_dir, 'compiled_packages.tgz'))
      end
    end

    describe '#cleanup' do
      it 'removes the download directory using the downloader' do
        group = double('compiled package group')
        blobstore_client = double('blobstore client')

        download_dir = '/path/to/download_dir'
        downloader = double('compiled package downloader', download: download_dir)

        CompiledPackageDownloader.stub(new: downloader)

        archiver = double('gzipper', compress: nil)
        TarGzipper.stub(new: archiver)

        output_dir = '/path/to/output_dir'
        exporter = CompiledPackagesExporter.new(group, blobstore_client, output_dir)
        exporter.tgz_path

        downloader.should_receive(:cleanup)
        exporter.cleanup
      end
    end
  end
end
