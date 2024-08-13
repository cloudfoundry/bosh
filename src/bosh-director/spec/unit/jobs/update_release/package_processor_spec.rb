require 'spec_helper'
require 'support/release_helper'
require 'digest'

module Bosh::Director
  module Jobs
    describe UpdateRelease::PackageProcessor do
      describe 'process_packages' do
        def process_packages
          UpdateRelease::PackageProcessor.process(
            release_version_model,
            release_model,
            name,
            version,
            manifest_packages,
            logger,
            fix,
          )
        end

        let(:manifest_packages) { [] }

        let(:release_version_model) { nil }
        let(:release_model) { nil }
        let(:name) { nil }
        let(:version) { nil }
        let(:fix) { false }

        context 'if a package fingerprint changes' do
          let(:manifest_packages) do
            [
              { 'name' => 'package_a', 'fingerprint' => 'b' },
            ]
          end

          let(:release_version_model) { instance_double(Models::ReleaseVersion) }

          let(:name) { 'release-name' }
          let(:version) { 'release-version' }

          before do
            allow(release_version_model).to receive(:packages).and_return [
              instance_double(Models::Package, name: 'package_a', fingerprint: 'a'),
            ]
          end

          it 'raises an exception' do
            expect do
              process_packages
            end.to raise_error(
              "package 'package_a' had different fingerprint in previously uploaded release 'release-name/release-version'",
            )
          end
        end

        context 'if there is no existing package with the same fingerprint' do
          let(:manifest_packages) do
            [new_package_metadata]
          end

          before do
            allow(release_version_model).to receive(:packages).and_return []
          end

          let(:new_package_metadata) do
            { 'name' => 'package-a', 'fingerprint' => 'print-a', 'sha1' => 'sha-a' }
          end

          let(:release_version_model) { instance_double(Models::ReleaseVersion) }

          it 'treats it as a new package' do
            new_packages, existing_packages, registered_packages = process_packages
            expect(existing_packages).to eq([])
            expect(new_packages).to eq([new_package_metadata.merge('compiled_package_sha1' => new_package_metadata['sha1'])])
            expect(registered_packages).to eq([])
          end
        end

        context 'if there exists a package that has a matching fingerprint' do
          let(:manifest_packages) do
            [new_package_metadata]
          end

          let(:release_model) { double(id: release.id) }

          let!(:release_version_model) do
            release.add_version(Models::ReleaseVersion.make)
          end

          let(:new_package_metadata) do
            {
              'name' => 'package-a',
              'version' => 'package-version',
              'fingerprint' => package_fingerprint,
              'sha1' => 'sha-a',
            }
          end

          let(:release) { FactoryBot.create(:models_release, name: 'appcloud') }
          let!(:package_model) do
            package_id = Models::Package.insert(
              name: package_name,
              fingerprint: package_fingerprint,
              sha1: model_sha,
              version: package_version,
              blobstore_id: blobstore_id,
              dependency_set_json: '{}',
              release_id: release.id,
            )
            Models::Package.where(id: package_id).first
          end

          let(:package_name) { 'package-a' }
          let(:package_version) { 'package-version' }
          let(:model_sha) { 'model-sha-a' }
          let(:package_fingerprint) { 'a' }
          let(:blobstore_id) { '1234' }

          context 'and is preexisting' do
            context 'and is not registered already' do
              context 'and has a non-nil blobstore id' do
                it 'does not change the package metadata' do
                  new_packages, existing_packages, registered_packages = process_packages
                  expect(new_packages).to eq([])
                  expect(existing_packages).to eq([[
                                                    package_model,
                                                    new_package_metadata.merge(
                                                      'compiled_package_sha1' => new_package_metadata['sha1'],
                                                    ),
                                                  ]])
                  expect(registered_packages).to eq([])
                end
              end

              context 'but has a nil blobstore id' do
                let(:blobstore_id) { nil }

                it 'copies the blobstore id from another package with the same fingerprint into the package metadata' do
                  another_blobstore_id = '2345'
                  another_model_sha1 = 'model-sha-b'
                  Models::Package.insert(
                    name: package_name,
                    fingerprint: package_fingerprint,
                    sha1: another_model_sha1,
                    version: package_version,
                    blobstore_id: another_blobstore_id,
                    dependency_set_json: '{}',
                    release_id: release.id + 1,
                  )

                  new_package_sha1 = new_package_metadata['sha1']

                  new_packages, existing_packages, registered_packages = process_packages
                  expect(new_packages).to eq([])
                  expect(existing_packages).to eq([[
                                                    package_model,
                                                    new_package_metadata.merge(
                                                      'compiled_package_sha1' => new_package_sha1,
                                                      'blobstore_id' => another_blobstore_id,
                                                      'sha1' => another_model_sha1,
                                                    ),
                                                  ]])
                  expect(registered_packages).to eq([])
                end
              end
            end

            context 'and is registered already' do
              before do
                release_version_model.add_package(package_model)
              end

              it 'includes it as a registered package and not an existing one' do
                new_packages, existing_packages, registered_packages = process_packages
                expect(new_packages).to eq([])
                expect(existing_packages).to eq([])
                expect(registered_packages).to eq([[
                                                    package_model,
                                                    new_package_metadata,
                                                  ]])
              end
            end
          end

          context 'and is not preexisting' do
            context 'and has a nil blobstore id' do
              let(:release_model) { double(id: release.id + 1) }

              let(:blobstore_id) { nil }

              it 'does not reuse the blob' do
                new_packages, existing_packages, registered_packages = process_packages

                new_package_sha1 = new_package_metadata['sha1']

                expect(new_packages).to eq([
                                             new_package_metadata.merge(
                                               'compiled_package_sha1' => new_package_sha1,
                                               'sha1' => new_package_sha1,
                                             ).except('blobstore_id'),
                                           ])
                expect(existing_packages).to eq([])
                expect(registered_packages).to eq([])
              end
            end

            context 'and has a blobstore id' do
              let(:blobstore_id) { '1234' }

              context 'but does not match release id' do
                let(:release_model) { double(id: release.id + 1) }

                it 'copies metadata from the existing package' do
                  new_package_sha1 = new_package_metadata['sha1']

                  new_packages, existing_packages, registered_packages = process_packages
                  expect(new_packages).to eq([
                                               new_package_metadata.merge(
                                                 'compiled_package_sha1' => new_package_sha1,
                                                 'blobstore_id' => blobstore_id,
                                                 'sha1' => model_sha,
                                               ),
                                             ])
                  expect(existing_packages).to eq([])
                  expect(registered_packages).to eq([])
                end
              end

              context 'but does not match name' do
                let(:package_name) { 'package-b' }

                it 'copies metadata from the existing package' do
                  new_package_sha1 = new_package_metadata['sha1']

                  new_packages, existing_packages, registered_packages = process_packages
                  expect(new_packages).to eq([
                                               new_package_metadata.merge(
                                                 'compiled_package_sha1' => new_package_sha1,
                                                 'blobstore_id' => blobstore_id,
                                                 'sha1' => model_sha,
                                               ),
                                             ])
                  expect(existing_packages).to eq([])
                  expect(registered_packages).to eq([])
                end
              end

              context 'but does not match version' do
                let(:package_version) { 'package-version-abcd' }

                it 'copies metadata from the existing package' do
                  new_package_sha1 = new_package_metadata['sha1']

                  new_packages, existing_packages, registered_packages = process_packages
                  expect(new_packages).to eq([
                                               new_package_metadata.merge(
                                                 'compiled_package_sha1' => new_package_sha1,
                                                 'blobstore_id' => blobstore_id,
                                                 'sha1' => model_sha,
                                               ),
                                             ])
                  expect(existing_packages).to eq([])
                  expect(registered_packages).to eq([])
                end
              end

              context 'and the release is being uploaded via --fix' do
                let(:release_model) { double(id: release.id + 1) }
                let(:fix) { true }

                it 'does not reuse the blob' do
                  new_packages, existing_packages, registered_packages = process_packages

                  new_package_sha1 = new_package_metadata['sha1']

                  expect(new_packages).to eq([
                                               new_package_metadata.merge(
                                                 'compiled_package_sha1' => new_package_sha1,
                                                 'sha1' => new_package_sha1,
                                               ).except('blobstore_id'),
                                             ])
                  expect(existing_packages).to eq([])
                  expect(registered_packages).to eq([])
                end
              end
            end
          end
        end
      end
    end
  end
end
