require 'spec_helper'

module Bosh
  module Director
    describe DeploymentPlan::ManifestValidator do
      let(:manifest_validator) { DeploymentPlan::ManifestValidator.new }
      let(:manifest_hash) { Bosh::Spec::Deployments.simple_manifest }

      describe '#validate_manifest' do

        it 'raises error when disk_types is present' do
          manifest_hash['disk_types'] = ['foo']
          expect {
            manifest_validator.validate(manifest_hash, nil)
          }.to raise_error(
              Bosh::Director::DeploymentInvalidProperty,
              "Deployment manifest contains 'disk_types' section, but it can only be used in cloud-config."
            )
        end

        it 'raises error when vm_type is present' do
          manifest_hash['vm_types'] = ['foo']
          expect {
            manifest_validator.validate(manifest_hash, nil)
          }.to raise_error(
              Bosh::Director::DeploymentInvalidProperty,
              "Deployment manifest contains 'vm_types' section, but it can only be used in cloud-config."
            )
        end

        it 'raises error when azs is present' do
          manifest_hash['azs'] = ['foo']
          expect {
            manifest_validator.validate(manifest_hash, nil)
          }.to raise_error(
              Bosh::Director::DeploymentInvalidProperty,
              "Deployment manifest contains 'azs' section, but it can only be used in cloud-config."
            )
        end

        context 'without cloud-config' do
          it 'accepts a manifest without jobs' do
            manifest_hash.delete('jobs')

            expect { manifest_validator.validate(manifest_hash, {}) }.not_to raise_error
          end

          it 'raises error when migrated_from is present' do
            manifest_hash['jobs'].first['migrated_from'] = [{'name' => 'old'}]
            expect {
              manifest_validator.validate(manifest_hash, {})
            }.to raise_error(
                Bosh::Director::DeploymentInvalidProperty,
                "Deployment manifest instance groups contain 'migrated_from', but it can only be used with cloud-config."
              )
          end
        end

        context 'with cloud-config' do
          let(:manifest_hash) do
            {
              'resource_pools' => ['fake-resource-pool'],
              'compilation' => ['fake-compilation'],
            }
          end
          let(:cloud_config_hash) { Bosh::Spec::Deployments.simple_cloud_config }

          it 'raises invalid property error' do
            expect {
              manifest_validator.validate(manifest_hash, cloud_config_hash)
            }.to raise_error(
                DeploymentInvalidProperty,
                'Deployment manifest should not contain cloud config properties: ["resource_pools", "compilation"]'
              )
          end
        end
      end
    end
  end
end
