require 'spec_helper'

module Bosh::Director
  module Jobs::Helpers
    describe ReleaseVersionDeleter do
      let(:release_deleter) { ReleaseDeleter.new(package_deleter, template_deleter, event_log, logger) }
      let(:compiled_package_deleter) { double('@todo', :delete => []) }
      let(:blob_deleter) { double('@todo', :delete => true) }
      let(:package_deleter) { PackageDeleter.new(compiled_package_deleter, blob_deleter, logger) }
      let(:template_deleter) { TemplateDeleter.new(blob_deleter, logger) }
      let(:logger) { Logging::Logger.new('/dev/null') }
      let(:event_log) { Config.event_log }
      subject { described_class.new(release_deleter, package_deleter, template_deleter, logger, event_log) }

      describe '#delete' do
        let(:release) { Models::Release.make(name: 'test_release') }
        let(:release_version) { Models::ReleaseVersion.make(version: 1, release: release) }
        let(:package) { Models::Package.make(name: 'test_package', release: release) }
        let(:template) { Models::Template.make(name: 'test_template', release: release) }

        before {
          package.add_release_version(release_version)
          template.add_release_version(release_version)
        }

        context 'when force is false' do
          let(:force) { false }
          context 'when used by existing deployment' do
            let(:deployment) { Models::Deployment.make(name: 'test_deployment')}
            before { deployment.add_release_version(release_version) }

            it 'does not delete the version' do
              expect {
                subject.delete(release_version, release, force)
              }.to raise_exception(Bosh::Director::ReleaseVersionInUse)
            end
          end

          context 'when not used by existing deployment' do
            context 'when package is used by another version' do
              let(:release_version2) { Models::ReleaseVersion.make(version:2, release:release)}

              before {
                package.add_release_version(release_version2)
              }

              it 'remove the current release_version package association' do
                subject.delete(release_version, release, force)
                expect(release_version.packages.length).to equal(0)
                expect(release_version2.packages.length).to equal(1)
                expect(release_version2.packages[0]).to eq(package)
              end
            end

            context 'when package deletion fails' do
              it 'tracks the error' do
                expect(package_deleter).to receive(:delete).with(package, force).and_return([Exception.new])
                errors = subject.delete(release_version, release, force)
                expect(errors.length).to equal(1)
              end
            end

            context 'when package is not used by another version' do
              context 'when template is used by another version' do
                let(:release_version2) { Models::ReleaseVersion.make(version:2, release:release)}

                before {
                  template.add_release_version(release_version2)
                }

                it 'remove the current release_version template association' do
                  subject.delete(release_version, release, force)
                  expect(release_version.templates.length).to equal(0)
                  expect(release_version2.templates.length).to equal(1)
                  expect(release_version2.templates[0]).to eq(template)
                end
              end

              context 'when template deletion fails' do
                it 'tracks the error' do
                  expect(template_deleter).to receive(:delete).with(template, force).and_return([Exception.new])
                  errors = subject.delete(release_version, release, force)
                  expect(errors.length).to equal(1)
                end
              end

              context 'when template is not used by another version' do
                it 'deletes the package, template and release_version record' do
                  subject.delete(release_version, release, force)
                  expect(Models::ReleaseVersion.all.length).to equal(0)
                  expect(Models::Package.all.length).to equal(0)
                  expect(Models::Template.all.length).to equal(0)
                  expect(Models::Release.all.length).to equal(0)
                end

                context 'when another release versions exist' do
                  before {
                    version2 = Models::ReleaseVersion.make(version: 2, release: release)
                    Models::Package.make(name: 'test_package', release: release).add_release_version(version2)
                    Models::Template.make(name: 'test_template', release: release).add_release_version(version2)
                  }

                  it 'does not delete the release db row' do
                    subject.delete(release_version, release, force)
                    expect(Models::ReleaseVersion.all.length).to equal(1)
                    expect(Models::Package.all.length).to equal(1)
                    expect(Models::Template.all.length).to equal(1)
                    expect(Models::Release.all.length).to equal(1)
                  end
                end
              end
            end
          end
        end

        context 'when force is true' do
          let(:force) { true }

          it 'deletes the release version' do
            expect(blob_deleter).to receive(:delete) do |blobstore_id, errors, force |
              errors << Exception.new
              true
            end

            subject.delete(release_version, release, force)
            expect(Models::ReleaseVersion.all.length).to equal(0)
            expect(Models::Package.all.length).to equal(0)
            expect(Models::Template.all.length).to equal(0)
            expect(Models::Release.all.length).to equal(0)
          end
        end
      end
    end
  end
end
