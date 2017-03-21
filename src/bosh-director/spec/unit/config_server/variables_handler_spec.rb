require 'spec_helper'

module Bosh::Director::ConfigServer
  describe VariablesHandler do
    let(:logger) { instance_double(Logging::Logger) }

    let(:deployment) { Bosh::Director::Models::Deployment.make(name: 'dep', manifest: '{}') }

    let (:variable_set) { Bosh::Director::Models::VariableSet.make(deployment: deployment) }
    let (:variable_set2) { Bosh::Director::Models::VariableSet.make(deployment: deployment) }
    let (:variable_set3) { Bosh::Director::Models::VariableSet.make(deployment: deployment) }

    let(:im1) { Bosh::Director::Models::Instance.make(variable_set: variable_set) }
    let(:im2) { Bosh::Director::Models::Instance.make(variable_set: variable_set) }
    let(:im3) { Bosh::Director::Models::Instance.make(variable_set: variable_set) }

    let(:ip1) { instance_double(Bosh::Director::DeploymentPlan::InstancePlan) }
    let(:ip2) { instance_double(Bosh::Director::DeploymentPlan::InstancePlan) }
    let(:ip3) { instance_double(Bosh::Director::DeploymentPlan::InstancePlan) }

    let(:ig1) { Bosh::Director::DeploymentPlan::InstanceGroup.new(logger) }
    let(:ig2) { Bosh::Director::DeploymentPlan::InstanceGroup.new(logger) }

    let (:instance_groups) { [ig1, ig2] }

    before do
      allow(ig1).to receive(:unignored_instance_plans).and_return([ip1, ip2])
      allow(ig2).to receive(:unignored_instance_plans).and_return([ip3])

      allow(ip1).to receive(:instance).and_return(im1)
      allow(ip2).to receive(:instance).and_return(im2)
      allow(ip3).to receive(:instance).and_return(im3)
    end

    context '#update_instance_plans_variable_set_id' do
      it "should update all instances to use current_variable_set id" do
        expect(im1).to receive(:variable_set=).with(variable_set2)
        expect(im2).to receive(:variable_set=).with(variable_set2)
        expect(im3).to receive(:variable_set=).with(variable_set2)

        VariablesHandler.update_instance_plans_variable_set_id(instance_groups, true, variable_set2)
      end
    end

    context '#mark_new_current_variable_set' do
      before do
        variable_current = Bosh::Director::Models::VariableSet.make(deployment: deployment)

        allow(deployment).to receive(:variable_sets).and_return([variable_current, variable_set, variable_set2])
        allow(deployment).to receive(:current_variable_set).and_return(variable_current)
      end

      it 'mark the old variable sets as old and the current as new' do
        Bosh::Director::ConfigServer::VariablesHandler.mark_new_current_variable_set(deployment)

        expect(deployment.variable_sets.size).to eq(3)
        expect(deployment.variable_sets[0].deployed_successfully).to be_truthy

        deployment.variable_sets.drop(1).each do |variable_set|
          expect(variable_set.deployed_successfully).to be_falsey
        end
      end
    end

    context '#remove_unused_variable_sets' do
      before do
        allow(deployment).to receive(:variable_sets).and_return([variable_set, variable_set2, variable_set3])
        allow(deployment).to receive(:current_variable_set).and_return(variable_set)

        allow(ig1).to receive(:needed_instance_plans).and_return([ip1, ip2])
        allow(ig2).to receive(:needed_instance_plans).and_return([ip3])

        im1.variable_set = variable_set
        im2.variable_set = variable_set2
        im3.variable_set = variable_set2

        allow(ip1).to receive(:instance).and_return(im1)
        allow(ip2).to receive(:instance).and_return(im2)
        allow(ip3).to receive(:instance).and_return(im3)
      end

      it 'asks the database to delete the unused variables' do
        expect(variable_set).to_not receive(:delete)
        expect(variable_set2).to_not receive(:delete)
        expect(variable_set3).to receive(:delete).once

        Bosh::Director::ConfigServer::VariablesHandler.remove_unused_variable_sets(deployment, instance_groups)
      end
    end
  end
end