require 'spec_helper'

module Bosh::Director
  module Jobs::Helpers
    describe NameVersionReleaseDeleter do
      subject(:name_version_release_deleter) { NameVersionReleaseDeleter.new(release_deleter, release_manager, release_version_deleter, per_spec_logger) }

      let(:release_version_deleter) { ReleaseVersionDeleter.new(release_deleter, package_deleter, template_deleter, per_spec_logger, event_log) }
      let(:release_manager) { Bosh::Director::Api::ReleaseManager.new }
      let(:release_deleter) { ReleaseDeleter.new(package_deleter, template_deleter, event_log, per_spec_logger) }
      let(:package_deleter) { PackageDeleter.new(compiled_package_deleter, blobstore, per_spec_logger) }
      let(:template_deleter) { TemplateDeleter.new(blobstore, per_spec_logger) }
      let(:compiled_package_deleter) { CompiledPackageDeleter.new(blobstore, per_spec_logger) }
      let(:blobstore) { instance_double(Bosh::Director::Blobstore::Client) }

      let(:release) { FactoryBot.create(:models_release, name: 'release-1') }
      let!(:release_version_1) { FactoryBot.create(:models_release_version, version: 1, release: release) }
      let!(:release_version_2) { FactoryBot.create(:models_release_version, version: 2, release: release) }
      let!(:package_1) { FactoryBot.create(:models_package, release: release, blobstore_id: 'package-blob-id-1') }
      let!(:package_2) { FactoryBot.create(:models_package, release: release, blobstore_id: 'package-blob-id-2') }
      let!(:template_1) { FactoryBot.create(:models_template, release: release, blobstore_id: 'template-blob-id-1') }
      let!(:template_2) { FactoryBot.create(:models_template, release: release, blobstore_id: 'template-blob-id-2') }
      let(:release_name) { release.name }
      let(:act) { name_version_release_deleter.find_and_delete_release(release_name, version, force) }
      let(:force) { false }
      let(:task) { FactoryBot.create(:models_task, id: 42) }
      let(:task_writer) {Bosh::Director::TaskDBWriter.new(:event_output, task.id)}
      let(:event_log) {Bosh::Director::EventLog::Log.new(task_writer)}

      before do
        allow(blobstore).to receive(:delete).with('package-blob-id-1')
        allow(blobstore).to receive(:delete).with('package-blob-id-2')
        allow(blobstore).to receive(:delete).with('template-blob-id-1')
        allow(blobstore).to receive(:delete).with('template-blob-id-2')
        package_1.add_release_version(release_version_1)
      end

      describe 'find_and_delete_release' do
        context 'when the version is not supplied' do
          let(:version) { nil }

          it 'deletes the whole release' do
            act
            expect(Models::Package.all).to be_empty
            expect(Models::Template.all).to be_empty
            expect(Models::ReleaseVersion.all).to be_empty
            expect(Models::Release.all).to be_empty
          end

          context 'when the things are not deletable' do
            before do
              allow(release_deleter).to receive(:delete).with(release, force).and_raise('wont')
            end

            it 'raises an error' do
              expect{
                act
              }.to raise_error(/wont/)
            end

            describe 'when forced' do
              let(:force) { true }
              before do
                allow(release_deleter).to receive(:delete).with(release, force).and_return('some error')
              end

              it 'deletes despite failures' do
                expect(act).to_not be_empty
              end
            end
          end
        end

        context 'when the version is supplied' do
          let(:version) { '1' }

          it 'deletes only the release version' do
            act
            expect(Models::ReleaseVersion.all.map(&:version)).to eq(['2'])
            expect(Models::Package.map(&:blobstore_id)).to eq(['package-blob-id-2'])
          end

          context 'when the release version is not deletable' do
            before do
              allow(release_version_deleter).to receive(:delete).with(release_version_1, release, force).and_raise('wont')
            end

            it 'raises an error' do
              expect {
                act
              }.to raise_error(/wont/)
            end
          end
        end
      end
    end
  end
end
