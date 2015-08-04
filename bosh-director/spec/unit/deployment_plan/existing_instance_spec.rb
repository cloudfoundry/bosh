require 'spec_helper'

describe Bosh::Director::DeploymentPlan::ExistingInstance do
  describe '#create_from_model' do
    describe 'instance availability zone' do
      it 'handles no AZ for legacy manifests' do
        deployment_manifest = Bosh::Spec::Deployments.legacy_manifest
        deployment_model = Bosh::Director::Models::Deployment.make(cloud_config: nil, manifest: YAML.dump(deployment_manifest))
        vm_model = Bosh::Director::Models::Vm.make(deployment: deployment_model)
        instance_model = Bosh::Director::Models::Instance.make(deployment: deployment_model, vm: vm_model, availability_zone: 'my-az')
        logger = instance_double(Logger)

        existing_instance = Bosh::Director::DeploymentPlan::ExistingInstance.create_from_model(instance_model, logger)

        expect(existing_instance.availability_zone).to be_nil
      end

      it 'gets the right az for deployments using cloud config' do
        cloud_manifest =Bosh::Spec::Deployments.simple_cloud_config.merge({
            'availability_zones' => [
              {
                'name' => 'wrong-az',
                'cloud_properties' => {'foo' => 'wrong'}
              },
              {
                'name' => 'my-az',
                'cloud_properties' => {'foo' => 'bar'}
              }
            ]
          })
        cloud_config_model = Bosh::Director::Models::CloudConfig.make(manifest: cloud_manifest)
        deployment_manifest = Bosh::Spec::Deployments.simple_manifest
        deployment_model = Bosh::Director::Models::Deployment.make(cloud_config: cloud_config_model, manifest: YAML.dump(deployment_manifest))
        vm_model = Bosh::Director::Models::Vm.make(deployment: deployment_model)
        instance_model = Bosh::Director::Models::Instance.make(deployment: deployment_model, vm: vm_model, availability_zone: 'my-az')
        logger = instance_double(Logger)

        existing_instance = Bosh::Director::DeploymentPlan::ExistingInstance.create_from_model(instance_model, logger)

        expect(existing_instance.availability_zone.name).to eq('my-az')
        expect(existing_instance.availability_zone.cloud_properties).to eq({'foo' => 'bar'})
      end
    end
  end
end
