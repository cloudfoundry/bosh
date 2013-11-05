require 'spec_helper'
require 'bosh/director/instance_preparer'

module Bosh::Director
  describe InstancePreparer do
    subject(:preparer) { described_class.new(instance, agent_client) }
    let(:instance) { instance_double('Bosh::Director::DeploymentPlan::Instance') }
    let(:agent_client) { instance_double('Bosh::Director::AgentClient') }

    describe '#prepare' do
      context "when state of the instance is 'detached'" do
        before { instance.stub(state: 'detached') }

        it 'does not send prepare message to the instance' do
          agent_client.should_not_receive(:prepare)
          preparer.prepare
        end
      end

      context "when state of the instance is not 'detached'" do
        before { instance.stub(state: 'not-detached') }
        before { instance.stub(spec: 'fake-spec') }

        it 'sends prepare message to the instance' do
          agent_client.should_receive(:prepare).with('fake-spec')
          preparer.prepare
        end

        context "when agent responds to 'prepare' message successfully" do
          before { agent_client.stub(:prepare).and_return(valid_response_for_prepare) }
          let(:valid_response_for_prepare) { {} }

          it 'does not raise an error' do
            expect { preparer.prepare }.to_not raise_error
          end
        end

        context "when agent does not respond to 'prepare' message " +
                'because that bosh-agent version did not support it' do
          before { agent_client.stub(:prepare).and_return('blah') }

          it 'does not raise an error since prepare message it just an optimization' do
            expect { preparer.prepare }.to_not raise_error
          end
        end

        context "when agent responds to 'prepare' message with an error" do
          before { agent_client.stub(:prepare).and_raise('blah') }

          it 'propagates an error' do
            expect { preparer.prepare }.to raise_error('blah')
          end
        end
      end
    end
  end
end
