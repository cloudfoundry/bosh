require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::PackageValidator do
    subject(:package_validator) { described_class.new(Config.logger) }
    let(:release) { Models::Release.make(name: 'release1') }
    let(:release_version_model) { Models::ReleaseVersion.make(release: release, version: 'version1') }

    describe '#validate' do
      let(:stemcell_model) { Models::Stemcell.make(operating_system: 'ubuntu', version: '3567.4') }

      context 'when there are valid compiled packages' do
        let(:package) { Models::Package.make(sha1: nil, blobstore_id: nil) }

        it 'does not fault if they have the exact stemcell version number' do
          compiled_package = Models::CompiledPackage.make(package: package, stemcell_os: 'ubuntu', stemcell_version: '3567.4')
          compiled_package.save
          release_version_model.add_package(package)
          package_validator.validate(release_version_model, stemcell_model)
          expect {
            package_validator.handle_faults
          }.to_not raise_error
        end

        it 'does not fault if the stemcell version number differs only in patch number' do
          compiled_package = Models::CompiledPackage.make(package: package, stemcell_os: 'ubuntu', stemcell_version: '3567.5')
          compiled_package.save
          release_version_model.add_package(package)
          package_validator.validate(release_version_model, stemcell_model)
          expect {
            package_validator.handle_faults
          }.to_not raise_error
        end
      end

      context 'when there are packages without sha and blobstore' do
        let(:invalid_package) { Models::Package.make(sha1: nil, blobstore_id: nil) }
        let(:valid_package) { Models::Package.make }

        before do
          release_version_model.add_package(invalid_package)
          release_version_model.add_package(valid_package)
        end

        context 'when packages is not compiled' do
          it 'creates a fault' do
            package_validator.validate(release_version_model, stemcell_model)
            expect {
              package_validator.handle_faults
            }.to raise_error PackageMissingSourceCode, /#{invalid_package.name}/
          end
        end
      end
    end

    describe '#handle_faults' do
      let(:stemcell_model1) { Models::Stemcell.make(name: 'stemcell1', version: 1) }
      let(:stemcell_model2) { Models::Stemcell.make(name: 'stemcell2', version: 2) }

      let(:invalid_package1) { Models::Package.make(sha1: nil, blobstore_id: nil, name: 'package1', version: 1) }
      let(:invalid_package2) { Models::Package.make(sha1: nil, blobstore_id: nil, name: 'package2', version: 2) }

      before do
        release_version_model.add_package(invalid_package1)
        release_version_model.add_package(invalid_package2)
        invalid_package2.dependency_set = ['package1']
        invalid_package2.save
      end

      context 'when validating for multiple stemcells' do
        it 'raises a correct error' do
          package_validator.validate(release_version_model, stemcell_model1)
          package_validator.validate(release_version_model, stemcell_model2)

          expect {
            package_validator.handle_faults
          }.to raise_error PackageMissingSourceCode, /
Can't use release 'release1\/version1'. It references packages without source code and are not compiled against intended stemcells:
 - 'package1\/1' against stemcell 'stemcell1\/1'
 - 'package1\/1' against stemcell 'stemcell2\/2'
 - 'package2\/2' against stemcell 'stemcell1\/1'
 - 'package2\/2' against stemcell 'stemcell2\/2'/
        end
      end

      context 'when validating for single stemcell' do
        it 'raises a correct error' do
          package_validator.validate(release_version_model, stemcell_model1)

          expect {
            package_validator.handle_faults
          }.to raise_error PackageMissingSourceCode, /
Can't use release 'release1\/version1'. It references packages without source code and are not compiled against stemcell 'stemcell1\/1':
 - 'package1\/1'
 - 'package2\/2'/
        end
      end
    end
  end
end
