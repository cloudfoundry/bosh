require 'spec_helper'

module Bosh::Director
  module Jobs::Helpers
    describe NameVersionReleaseDeleter do
      subject(:name_version_release_deleter) { NameVersionReleaseDeleter.new(release_deleter, release_manager, release_version_deleter, logger) }

      let(:release_version_deleter) { ReleaseVersionDeleter.new(release_deleter, package_deleter, template_deleter, logger, Config.event_log) }
      let(:release_manager) { Bosh::Director::Api::ReleaseManager.new }
      let(:release_deleter) { ReleaseDeleter.new(package_deleter, template_deleter, Config.event_log, logger) }
      let(:package_deleter) { PackageDeleter.new(compiled_package_deleter, blob_deleter, logger) }
      let(:template_deleter) { TemplateDeleter.new(blob_deleter, logger) }
      let(:compiled_package_deleter) { CompiledPackageDeleter.new(blob_deleter, logger) }
      let(:blob_deleter) { BlobDeleter.new(blobstore, logger) }
      let(:blobstore) { instance_double(Bosh::Blobstore::BaseClient) }

      let(:release) { Models::Release.make(name: 'release-1') }
      let!(:release_version_1) { Models::ReleaseVersion.make(version: 1, release: release) }
      let!(:release_version_2) { Models::ReleaseVersion.make(version: 2, release: release) }
      let!(:package_1) { Models::Package.make(release: release, blobstore_id: 'package-blob-id-1') }
      let!(:package_2) { Models::Package.make(release: release, blobstore_id: 'package-blob-id-2') }
      let!(:template_1) { Models::Template.make(release: release, blobstore_id: 'template-blob-id-1') }
      let!(:template_2) { Models::Template.make(release: release, blobstore_id: 'template-blob-id-2') }
      let(:release_name) { release.name }
      let(:errors) { name_version_release_deleter.find_and_delete_release(release_name, version, force) }
      let(:force) { false }

      before do
        allow(blobstore).to receive(:delete).with('package-blob-id-1')
        allow(blobstore).to receive(:delete).with('package-blob-id-2')
        allow(blobstore).to receive(:delete).with('template-blob-id-1')
        allow(blobstore).to receive(:delete).with('template-blob-id-2')
        package_1.add_release_version(release_version_1)
      end

      describe 'find_and_delete_release' do
        describe 'when the version is not supplied' do
          let(:version) { nil }

          it 'deletes the WHOLE release' do
            expect(errors).to be_empty
            expect(Models::Package.all).to be_empty
            expect(Models::Template.all).to be_empty
            expect(Models::ReleaseVersion.all).to be_empty
            expect(Models::Release.all).to be_empty
          end

          describe 'when the things are not deletable' do
            before do
              allow(blobstore).to receive(:delete).with('package-blob-id-1').and_raise('wont')
            end

            it 'returns errors' do
              expect(errors).to_not be_empty
              expect(Models::Package.all.map(&:blobstore_id)).to eq(['package-blob-id-1'])
              expect(Models::ReleaseVersion.all.map(&:version)).to eq(['1', '2'])
              expect(Models::Template.all).to be_empty
              expect(Models::Release.all.map(&:name)).to eq(['release-1'])
            end

            describe 'when forced' do
              let(:force) { true }

              it 'deletes despite failures' do
                expect(errors).to_not be_empty
                expect(Models::Package.all).to be_empty
                expect(Models::Template.all).to be_empty
                expect(Models::ReleaseVersion.all).to be_empty
                expect(Models::Release.all).to be_empty
              end
            end
          end
        end

        describe 'when the version is supplied' do
          let(:version) { 1 }

          it 'deletes only the release version' do
            expect(errors).to be_empty
            expect(Models::ReleaseVersion.all.map(&:version)).to eq(['2'])
            expect(Models::Package.map(&:blobstore_id)).to eq(['package-blob-id-2'])
          end

          describe 'when the things are not deletable' do
            before do
              allow(blobstore).to receive(:delete).with('package-blob-id-1').and_raise('wont')
            end

            it 'returns errors' do
              expect(errors.map(&:message)).to eq(['wont'])
            end

            describe 'when forced' do
              let(:force) { true }

              it 'deletes the package despite failures' do
                expect(errors).to_not be_empty
                expect(Models::Package.all.map(&:blobstore_id)).to eq(['package-blob-id-2'])
                expect(Models::Template.all.map(&:blobstore_id)).to eq(['template-blob-id-1', 'template-blob-id-2'])
                expect(Models::ReleaseVersion.all.map(&:version)).to eq(['2'])
                expect(Models::Release.all.map(&:name)).to eq(['release-1'])
              end
            end
          end
        end
      end
    end
  end
end
