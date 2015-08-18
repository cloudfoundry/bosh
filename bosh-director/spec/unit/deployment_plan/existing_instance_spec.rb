require 'spec_helper'

describe Bosh::Director::DeploymentPlan::ExistingInstance do
  let(:logger) { instance_double(Logger, debug: nil) }
  let(:instance_model) do
    deployment_manifest = Bosh::Spec::Deployments.legacy_manifest
    deployment_model = Bosh::Director::Models::Deployment.make(cloud_config: nil, manifest: YAML.dump(deployment_manifest))
    vm_model = Bosh::Director::Models::Vm.make(deployment: deployment_model)
    Bosh::Director::Models::Instance.make(deployment: deployment_model, vm: vm_model, availability_zone: 'my-az')
  end

  let(:existing_instance) do
    Bosh::Director::DeploymentPlan::ExistingInstance.create_from_model(instance_model, logger)
  end

  describe '#delete' do
    before do
      Bosh::Director::Models::IpAddress.make(instance: instance_model)
      Bosh::Director::Models::IpAddress.make(instance: instance_model)
    end

    it 'deletes instance IP reservations' do
      expect(Bosh::Director::Models::IpAddress.all.size).to eq(2)
      existing_instance.delete
      expect(Bosh::Director::Models::IpAddress.all.size).to eq(0)
    end
  end

  context 'when instance does not have VM' do
    it 'can be created' do
      instance_model = Bosh::Director::Models::Instance.make(job: 'fake-job', index: 5)
      instance_model.vm = nil

      instance = described_class.create_from_model(instance_model, logger)
      expect(instance.to_s).to eq('fake-job/5')
    end
  end
end
