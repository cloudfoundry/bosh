require 'spec_helper'

module Bosh::Director
  describe PostDeploymentScriptRunner do
    context "Given a deployment instance" do
      let(:agent) { instance_double(
                        'Bosh::Director::AgentClient',
      )}
      let(:instance_data_set) { instance_double(
                            'Sequel::Dataset'
      )}
      let(:instance) { instance_double(
                           'Bosh::Director::Models::Instance',
                           credentials: "",
                           agent_id: ""
      )}
      let(:agent) { instance_double(
                        'Bosh::Director::AgentClient'
      )}
      before do
        allow(Bosh::Director::Models::Instance).to receive(:filter).and_return(instance_data_set)
        allow(instance_data_set).to receive(:exclude).and_return(instance_data_set)
        allow(instance_data_set).to receive(:all).and_return([instance,instance])
        allow(Bosh::Director::AgentClient).to receive(:with_vm_credentials_and_agent_id).and_return(agent)
      end

      it "runs 'post_deploy' on each instance of that deployment" do
        allow(Bosh::Director::Config).to receive(:enable_post_deploy).and_return(true)
        expect(agent).to receive(:run_script).twice
        described_class.run_post_deploys_after_resurrection({})
      end
    end
  end
end
