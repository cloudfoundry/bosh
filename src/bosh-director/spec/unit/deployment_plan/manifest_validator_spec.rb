require 'spec_helper'

module Bosh
  module Director
    describe DeploymentPlan::ManifestValidator do
      let(:manifest_validator) { DeploymentPlan::ManifestValidator.new }
      let(:manifest_hash) { Bosh::Spec::Deployments.minimal_manifest }

      describe '#validate_manifest' do
        it 'raises error when disk_types is present' do
          manifest_hash['disk_types'] = ['foo']
          expect do
            manifest_validator.validate(manifest_hash)
          end.to raise_error(
            Bosh::Director::DeploymentInvalidProperty,
            "Deployment manifest contains 'disk_types' section, but this can only be set in a cloud-config.",
          )
        end

        it 'raises error when vm_type is present' do
          manifest_hash['vm_types'] = ['foo']
          expect do
            manifest_validator.validate(manifest_hash)
          end.to raise_error(
            Bosh::Director::DeploymentInvalidProperty,
            "Deployment manifest contains 'vm_types' section, but this can only be set in a cloud-config.",
          )
        end

        it 'raises error when azs is present' do
          manifest_hash['azs'] = ['foo']
          expect do
            manifest_validator.validate(manifest_hash)
          end.to raise_error(
            Bosh::Director::DeploymentInvalidProperty,
            "Deployment manifest contains 'azs' section, but this can only be set in a cloud-config.",
          )
        end

        it 'raises error when compilation is present' do
          manifest_hash['compilation'] = ['foo']
          expect do
            manifest_validator.validate(manifest_hash)
          end.to raise_error(
            Bosh::Director::DeploymentInvalidProperty,
            "Deployment manifest contains 'compilation' section, but this can only be set in a cloud-config.",
          )
        end

        it 'raises a deprecation error when networks is present as a manifest key' do
          manifest_hash['networks'] = ['foo']
          expect do
            manifest_validator.validate(manifest_hash)
          end.to raise_error(
            Bosh::Director::V1DeprecatedNetworks,
            "Deployment 'networks' are no longer supported. Network definitions must now be provided in a cloud-config.",
          )
        end

        it 'raises a deprecation error when disk_pools is present as a manifest key' do
          manifest_hash['disk_pools'] = ['foo']
          expect do
            manifest_validator.validate(manifest_hash)
          end.to raise_error(
            Bosh::Director::V1DeprecatedDiskPools,
            'disk_pools is no longer supported. Disk definitions must now be provided as disk_types in a cloud-config',
          )
        end

        it 'raises a deprecation error when jobs is present as a manifest key' do
          manifest_hash['jobs'] = ['foo']
          expect do
            manifest_validator.validate(manifest_hash)
          end.to raise_error(
            Bosh::Director::V1DeprecatedJob,
            'Jobs are no longer supported, please use instance groups instead',
          )
        end

        it 'raises a deprecation error when resource_pools is present as a manifest key' do
          manifest_hash['resource_pools'] = ['foo']
          expect do
            manifest_validator.validate(manifest_hash)
          end.to raise_error(
            Bosh::Director::V1DeprecatedResourcePools,
            'resource_pools is no longer supported. You must now define resources in a cloud-config',
          )
        end

        it 'raises error when both os and name are specified for a stemcell' do
          manifest_hash['stemcells'][0]['name'] = 'the-name'

          expect do
            manifest_validator.validate(manifest_hash)
          end.to raise_error(
            Bosh::Director::StemcellBothNameAndOS,
            %[Properties 'os' and 'name' are both specified for stemcell, choose one. ({"alias"=>"default", "os"=>"toronto-os", "version"=>"latest", "name"=>"the-name"})],
          )
        end
      end
    end
  end
end
