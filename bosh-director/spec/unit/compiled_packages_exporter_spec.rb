require 'spec_helper'
require 'bosh/director/compiled_packages_exporter'

module Bosh::Director
  describe CompiledPackagesExporter do
    subject(:exporter) { described_class.new(group, blobstore_client) }
    let(:group) { instance_double('Bosh::Director::CompiledPackageGroup') }
    let(:blobstore_client) { double('blobstore client') }

    describe '#export' do
      let(:download_dir) { '/tmp/path/to/download_dir' }

      before { Core::TarGzipper.stub(new: archiver) }
      let(:archiver) { instance_double('Bosh::Director::Core::TarGzipper') }

      before { CompiledPackageDownloader.stub(:new).with(group, blobstore_client).and_return(downloader) }
      let(:downloader) { instance_double('Bosh::Director::CompiledPackageDownloader', cleanup: nil) }

      before { CompiledPackageManifest.stub(:new).with(group).and_return(manifest) }
      let(:manifest) { instance_double('Bosh::Director::CompiledPackageManifest') }

      context 'when none of the steps fail' do
        it 'exports archived compiled packages that were downloaded from blobstore' do
          downloader.should_receive(:download).with(no_args).and_return(download_dir)

          manifest.should_receive(:write).with("#{download_dir}/compiled_packages.MF")

          output_path = '/path/to/output.tar.gz'
          archiver.should_receive(:compress).with(
            download_dir, ['compiled_packages', 'compiled_packages.MF'], output_path)

          exporter.export(output_path)
        end

        it 'cleans up the downloaded artifacts' do
          downloader.stub(download: download_dir)
          manifest.stub(write: nil)
          archiver.stub(compress: nil)

          expect(downloader).to receive(:cleanup).with(no_args)
          exporter.export('/path/to/output.tar.gz')
        end
      end

      context 'when download fails' do
        before { downloader.stub(:download).and_raise(error) }
        let(:error) { Exception.new('error') }

        it 'cleans up the downloaded artifacts' do
          manifest.stub(write: nil)
          archiver.stub(compress: nil)

          expect(downloader).to receive(:cleanup).with(no_args)
          expect { exporter.export('/path/to/output.tar.gz') }.to raise_error(error)
        end
      end

      context 'when manifest generation fails' do
        before { manifest.stub(:write).and_raise(error) }
        let(:error) { Exception.new('error') }

        it 'cleans up the downloaded artifacts' do
          downloader.stub(download: download_dir)
          archiver.stub(compress: nil)

          expect(downloader).to receive(:cleanup).with(no_args)
          expect { exporter.export('/path/to/output.tar.gz') }.to raise_error(error)
        end
      end

      context 'when archiving fails fails' do
        before { archiver.stub(:compress).and_raise(error) }
        let(:error) { Exception.new('error') }

        it 'cleans up the downloaded artifacts' do
          downloader.stub(download: download_dir)
          manifest.stub(write: nil)

          expect(downloader).to receive(:cleanup).with(no_args)
          expect { exporter.export('/path/to/output.tar.gz') }.to raise_error(error)
        end
      end
    end
  end
end
