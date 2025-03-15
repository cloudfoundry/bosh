require 'spec_helper'

module Bosh::Director
  describe DirectorDnsStateUpdater do
    subject { described_class.new }
    let(:instance) { FactoryBot.create(:models_instance) }
    let(:instance_plan) do
      instance_double(Bosh::Director::DeploymentPlan::InstancePlan, instance: deployment_plan_instance)
    end
    let(:deployment_plan_instance) do
      instance_double(
        Bosh::Director::DeploymentPlan::Instance,
        model: instance,
      )
    end

    let(:dns_record_info) { ['asdf-asdf-asdf-asdf', 'my-instance-group', 'az1', 'my-network', 'my-deployment', '1.2.3.4'] }
    let(:localdns_manager) { instance_double(LocalDnsManager) }

    before do
      allow(LocalDnsManager).to receive(:create).with(
        Config.root_domain,
        Config.logger,
      ).and_return(localdns_manager)
    end

    describe '#update_dns_for_instance' do
      it 'calls out to dns manager to update records for instance and flush cache' do
        expect(localdns_manager).to receive(:update_dns_record_for_instance).with(instance_plan)

        subject.update_dns_for_instance(instance_plan, dns_record_info)
      end
    end
  end
end
