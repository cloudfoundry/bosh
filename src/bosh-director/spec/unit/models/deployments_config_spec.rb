require 'spec_helper'

module Bosh::Director::Models
  describe DeploymentsConfig do
    subject!(:deployment_config) do
      d = described_class.new
      d.config = config
      d.deployment = deployment
      d.save
      d
    end
    let(:config) { Config.make(type: 'fake-config') }
    let(:deployment) { Deployment.make(name: 'fake-deployment') }

    it 'can create a deployment config' do
      expect(deployment_config.config).to eq(config)
      expect(deployment_config.deployment).to eq(deployment)
    end

    describe '#deployments_and_configs' do
      let(:other_deployment) { Deployment.make(name: 'other-deployment') }
      let!(:other_deployment_config) do
        d = described_class.new
        d.config = config
        d.deployment = other_deployment
        d.save
        d
      end

      it 'lists only results which match the deployment name' do
        deployment_configs = DeploymentsConfig.by_deployment_name('fake-deployment')
        expect(deployment_configs.all.count).to eq(1)
        deployment_config = deployment_configs.all.first
        expect(deployment_config.deployment.name).to eq('fake-deployment')
      end
    end
  end
end
