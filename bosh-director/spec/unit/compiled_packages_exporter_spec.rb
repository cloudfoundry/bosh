require 'spec_helper'
require 'bosh/director/compiled_packages_exporter'

module Bosh::Director
  describe CompiledPackagesExporter do
    subject(:exporter) { described_class.new(group, blobstore_client) }
    let(:group) { instance_double('Bosh::Director::CompiledPackageGroup') }
    let(:blobstore_client) { double('blobstore client') }

    describe '#export' do
      let(:download_dir) { '/tmp/path/to/download_dir' }

      before { allow(Core::TarGzipper).to receive_messages(new: archiver) }
      let(:archiver) { instance_double('Bosh::Director::Core::TarGzipper') }

      before { allow(CompiledPackageDownloader).to receive(:new).with(group, blobstore_client).and_return(downloader) }
      let(:downloader) { instance_double('Bosh::Director::CompiledPackageDownloader', cleanup: nil) }

      before { allow(CompiledPackageManifest).to receive(:new).with(group).and_return(manifest) }
      let(:manifest) { instance_double('Bosh::Director::CompiledPackageManifest') }

      context 'when none of the steps fail' do
        it 'exports archived compiled packages that were downloaded from blobstore' do
          expect(downloader).to receive(:download).with(no_args).and_return(download_dir)

          expect(manifest).to receive(:write).with("#{download_dir}/compiled_packages.MF")

          output_path = '/path/to/output.tar.gz'
          expect(archiver).to receive(:compress).with(
            download_dir, ['compiled_packages', 'compiled_packages.MF'], output_path)

          exporter.export(output_path)
        end

        it 'cleans up the downloaded artifacts' do
          allow(downloader).to receive_messages(download: download_dir)
          allow(manifest).to receive_messages(write: nil)
          allow(archiver).to receive_messages(compress: nil)

          expect(downloader).to receive(:cleanup).with(no_args)
          exporter.export('/path/to/output.tar.gz')
        end
      end

      context 'when download fails' do
        before { allow(downloader).to receive(:download).and_raise(error) }
        let(:error) { Exception.new('error') }

        it 'cleans up the downloaded artifacts' do
          allow(manifest).to receive_messages(write: nil)
          allow(archiver).to receive_messages(compress: nil)

          expect(downloader).to receive(:cleanup).with(no_args)
          expect { exporter.export('/path/to/output.tar.gz') }.to raise_error(error)
        end
      end

      context 'when manifest generation fails' do
        before { allow(manifest).to receive(:write).and_raise(error) }
        let(:error) { Exception.new('error') }

        it 'cleans up the downloaded artifacts' do
          allow(downloader).to receive_messages(download: download_dir)
          allow(archiver).to receive_messages(compress: nil)

          expect(downloader).to receive(:cleanup).with(no_args)
          expect { exporter.export('/path/to/output.tar.gz') }.to raise_error(error)
        end
      end

      context 'when archiving fails fails' do
        before { allow(archiver).to receive(:compress).and_raise(error) }
        let(:error) { Exception.new('error') }

        it 'cleans up the downloaded artifacts' do
          allow(downloader).to receive_messages(download: download_dir)
          allow(manifest).to receive_messages(write: nil)

          expect(downloader).to receive(:cleanup).with(no_args)
          expect { exporter.export('/path/to/output.tar.gz') }.to raise_error(error)
        end
      end
    end
  end
end
