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

        context "and agent responds to 'prepare' message successfully" do
          before { agent_client.stub(:prepare).and_return(valid_response_for_prepare) }
          let(:valid_response_for_prepare) { {} }

          it 'does not raise an error' do
            expect { preparer.prepare }.not_to raise_error
          end

          context 'and agent responds with an error' do
            before { agent_client.stub(:prepare).and_raise(error) }
            let(:error) { RpcRemoteException.new('something else went wrong') }

            it 'propagates the error' do
              expect { preparer.prepare }.to raise_error(error)
            end
          end
        end

        context "when agent does not know how to respond to 'prepare'" do
          before { agent_client.stub(:prepare).and_raise(error) }
          let(:error) { RpcRemoteException.new('unknown message {"method"=>"prepare", "blah"=>"blah"}') }

          it 'tolerates the error since prepare message is an optimization and old agents might not know it' do
            expect { preparer.prepare }.not_to raise_error
          end
        end
      end
    end
  end
end
