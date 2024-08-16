require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::PackageValidator do
    include Support::StemcellHelpers

    subject(:package_validator) { described_class.new(Config.logger) }
    let(:release) { FactoryBot.create(:models_release, name: 'release1') }
    let(:release_version_model) { FactoryBot.create(:models_release_version, release: release, version: 'version1') }

    describe '#validate' do
      let(:stemcell) { make_stemcell(operating_system: 'ubuntu', version: '3567.4') }

      context 'when there are valid compiled packages' do
        let(:package) { FactoryBot.create(:models_package, sha1: nil, blobstore_id: nil) }

        it 'does not fault if they have the exact stemcell version number' do
          compiled_package = FactoryBot.create(:models_compiled_package, package: package, stemcell_os: 'ubuntu', stemcell_version: '3567.4')
          compiled_package.save
          release_version_model.add_package(package)
          package_validator.validate(release_version_model, stemcell, [nil], [])
          expect do
            package_validator.handle_faults
          end.to_not raise_error
        end

        it 'does not fault if the stemcell version number differs only in patch number' do
          compiled_package = FactoryBot.create(:models_compiled_package, package: package, stemcell_os: 'ubuntu', stemcell_version: '3567.5')
          compiled_package.save
          release_version_model.add_package(package)
          package_validator.validate(release_version_model, stemcell, [nil], [])
          expect do
            package_validator.handle_faults
          end.to_not raise_error
        end
      end

      context 'when there are packages without sha and blobstore' do
        let(:invalid_package) { FactoryBot.create(:models_package, sha1: nil, blobstore_id: nil) }
        let(:valid_package) { FactoryBot.create(:models_package) }

        before do
          release_version_model.add_package(invalid_package)
          release_version_model.add_package(valid_package)
        end

        context 'when packages is not compiled' do
          it 'creates a fault' do
            package_validator.validate(release_version_model, stemcell, [invalid_package.name, valid_package.name], [])
            expect do
              package_validator.handle_faults
            end.to raise_error PackageMissingSourceCode, /#{invalid_package.name}/
          end
        end
      end

      context 'when there is exported_from' do
        let(:package) { FactoryBot.create(:models_package, sha1: nil, blobstore_id: nil) }
        let(:exported_from) { [DeploymentPlan::ReleaseVersionExportedFrom.new('ubuntu', '3567.1')] }

        context 'when there is a valid compiled package' do
          it 'does not fault if there is an exact match' do
            compiled_package = FactoryBot.create(:models_compiled_package, package: package, stemcell_os: 'ubuntu', stemcell_version: '3567.1')
            compiled_package.save
            release_version_model.add_package(package)
            package_validator.validate(release_version_model, stemcell, [package.name], exported_from)
            expect do
              package_validator.handle_faults
            end.to_not raise_error
          end

          it 'creates a fault if there is a difference in patch version' do
            compiled_package = FactoryBot.create(:models_compiled_package, package: package, stemcell_os: 'ubuntu', stemcell_version: '3567.4')
            compiled_package.save
            release_version_model.add_package(package)
            package_validator.validate(release_version_model, stemcell, [package.name], exported_from)
            expect do
              package_validator.handle_faults
            end.to raise_error PackageMissingExportedFrom, /#{package.name}/
          end
        end

        context 'when packages are not compiled' do
          let(:package) { FactoryBot.create(:models_package) }

          it 'creates a fault' do
            release_version_model.add_package(package)
            package_validator.validate(release_version_model, stemcell, [package.name], exported_from)
            expect do
              package_validator.handle_faults
            end.to raise_error PackageMissingExportedFrom, %r{ubuntu/3567\.1}
          end
        end

        context 'when multiple exported_from' do
          let(:stemcell) { make_stemcell(operating_system: 'ubuntu-xenial', version: '250.17') }
          let(:exported_from) do
            [
              DeploymentPlan::ReleaseVersionExportedFrom.new('ubuntu-trusty', '3567.1'),
              DeploymentPlan::ReleaseVersionExportedFrom.new('ubuntu-xenial', '250.17'),
            ]
          end

          context 'and there is a match' do
            before do
              FactoryBot.create(:models_compiled_package, package: package, stemcell_os: 'ubuntu-xenial', stemcell_version: '250.17').save
            end

            it 'should find a compiled package' do
              release_version_model.add_package(package)
              package_validator.validate(release_version_model, stemcell, [package.name], exported_from)
              expect do
                package_validator.handle_faults
              end.to_not raise_error
            end
          end

          context 'and there are no matches' do
            it 'should generate a fault' do
              release_version_model.add_package(package)
              package_validator.validate(release_version_model, stemcell, [package.name], exported_from)
              expect do
                package_validator.handle_faults
              end.to raise_error PackageMissingExportedFrom, %r{
Can't use release 'release1\/version1':
Packages must be exported from stemcell 'ubuntu-xenial\/250.17', but some packages are not compiled for this stemcell:
 - '#{package.desc}'}
            end
          end
        end
      end
    end

    describe '#handle_faults' do
      let(:stemcell1) { make_stemcell(name: 'stemcell1', version: 1) }
      let(:stemcell2) { make_stemcell(name: 'stemcell2', version: 2) }

      let(:invalid_package1) { FactoryBot.create(:models_package, sha1: nil, blobstore_id: nil, name: 'package1', version: 1) }
      let(:invalid_package2) { FactoryBot.create(:models_package, sha1: nil, blobstore_id: nil, name: 'package2', version: 2) }

      let(:job_packages) { %w[package1 package2] }

      before do
        release_version_model.add_package(invalid_package1)
        release_version_model.add_package(invalid_package2)
        invalid_package2.dependency_set = ['package1']
        invalid_package2.save
      end

      context 'when validating for multiple stemcells' do
        it 'raises a correct error' do
          package_validator.validate(release_version_model, stemcell1, job_packages, [])
          package_validator.validate(release_version_model, stemcell2, job_packages, [])

          expect do
            package_validator.handle_faults
          end.to raise_error PackageMissingSourceCode, %r{
Can't use release 'release1\/version1'. It references packages without source code and are not compiled against intended stemcells:
 - 'package1\/1' against stemcell 'stemcell1\/1'
 - 'package1\/1' against stemcell 'stemcell2\/2'
 - 'package2\/2' against stemcell 'stemcell1\/1'
 - 'package2\/2' against stemcell 'stemcell2\/2'}
        end
      end

      context 'when validating for single stemcell' do
        it 'raises a correct error' do
          package_validator.validate(release_version_model, stemcell1, job_packages, [])

          expect { package_validator.handle_faults }.to raise_error PackageMissingSourceCode, %r{
Can't use release 'release1/version1'. It references packages without source code and are not compiled against stemcell 'stemcell1/1':
 - 'package1/1'
 - 'package2/2'}
        end

        context 'when required packages are specified in job' do
          let(:job_packages) { %w[package2] }

          before do
            invalid_package2.dependency_set = []
            invalid_package2.save
          end

          it 'should only fail for listed package in job' do
            package_validator.validate(release_version_model, stemcell1, job_packages, [])

            expect { package_validator.handle_faults }.to raise_error PackageMissingSourceCode, %r{
Can't use release 'release1/version1'. It references packages without source code and are not compiled against stemcell 'stemcell1/1':
 - 'package2/2'}
          end
        end
      end

      context 'when there are ExportedFrom faults' do
        let(:stemcell) { make_stemcell(operating_system: 'ubuntu', version: '3567.4') }
        let(:exported_from) { [DeploymentPlan::ReleaseVersionExportedFrom.new('ubuntu', '3567.1')] }

        it 'lists the exported_from that is missing' do
          package_validator.validate(release_version_model, stemcell, job_packages, exported_from)
          expect do
            package_validator.handle_faults
          end.to raise_error PackageMissingExportedFrom, %r{
Can't use release 'release1/version1':
Packages must be exported from stemcell 'ubuntu/3567.1', but some packages are not compiled for this stemcell:
 - 'package1/1'
 - 'package2/2'}
        end
      end

      context 'when a stemcell was not listed in exported_from' do
        let(:stemcell) { make_stemcell(operating_system: 'centos', version: '123.4') }
        let(:exported_from) { [DeploymentPlan::ReleaseVersionExportedFrom.new('ubuntu', '3567.1')] }

        it 'lists the exported_from that is missing' do
          package_validator.validate(release_version_model, stemcell, job_packages, exported_from)
          expect do
            package_validator.handle_faults
          end.to raise_error StemcellNotPresentInExportedFrom, %r{
Can't use release 'release1/version1': expected to find stemcell for 'centos/123\.4' to be configured in exported_from}
        end
      end
    end
  end
end
