require 'spec_helper'
require 'bosh/director/compiled_packages_exporter'

module Bosh::Director
  describe CompiledPackagesExporter do
    describe '#tgz_path' do
      it 'downloads the compiled packages from blobstore using CompiledPackageDownloader and creates a gzipped tar using DirGzipper' do
        group = double('compiled package group')
        downloader = double('compiled package downloader')
        download_dir = '/path/to/download_dir'
        downloader.stub(:download).with(no_args).and_return(download_dir)
        blobstore_client = double('blobstore client')
        CompiledPackageDownloader.stub(:new).with(group, blobstore_client).and_return(downloader)

        archiver = double('gzipper')
        tgz_file = double('file')
        archiver.stub(:compress).with(download_dir, '*', File.join(download_dir, 'compiled_packages.tgz')).and_return(tgz_file)
        TarGzipper.stub(:new).and_return(archiver)

        fake_tgz_path = double('fake path')
        tgz_file.stub(:path).with(no_args).and_return(fake_tgz_path)
        exporter = CompiledPackagesExporter.new(group, blobstore_client)
        exporter.tgz_path.should eq(fake_tgz_path)
      end
    end
  end
end
