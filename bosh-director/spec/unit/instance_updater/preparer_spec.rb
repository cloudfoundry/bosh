require 'spec_helper'
require 'logger'
require 'bosh/director/instance_updater/preparer'

module Bosh::Director
  describe InstanceUpdater::Preparer do
    subject(:preparer) { described_class.new(instance, agent_client, logger) }
    let(:instance) { instance_double('Bosh::Director::DeploymentPlan::Instance') }
    let(:agent_client) { instance_double('Bosh::Director::AgentClient') }

    describe '#prepare' do
      def self.it_does_not_send_prepare
        it 'does not send prepare message to the instance' do
          expect(agent_client).not_to receive(:prepare)
          preparer.prepare
        end
      end

      context "when instance's resource pool has not changed" do
        before { allow(instance).to receive(:resource_pool_changed?).with(no_args).and_return(false) }

        context "when state of the instance is not 'detached'" do
          before { allow(instance).to receive(:state).with(no_args).and_return('not-detached') }
          before { allow(instance).to receive_messages(spec: 'fake-spec') }

          it 'sends prepare message to the instance' do
            expect(agent_client).to receive(:prepare).with('fake-spec')
            preparer.prepare
          end

          context "and agent responds to 'prepare' message successfully" do
            before { allow(agent_client).to receive(:prepare).and_return(valid_response_for_prepare) }
            let(:valid_response_for_prepare) { {} }

            it 'does not raise an error' do
              expect { preparer.prepare }.to_not raise_error
            end

            context 'and agent responds with an error' do
              before { allow(agent_client).to receive(:prepare).and_raise(error) }
              let(:error) { RpcRemoteException.new('fake-agent-error') }

              it 'does not propagate the error because all errors from prepare are ignored' do
                expect { preparer.prepare }.to_not raise_error
              end
            end
          end

          context "when agent does not know how to respond to 'prepare'" do
            before { allow(agent_client).to receive(:prepare).and_raise(error) }
            let(:error) { RpcRemoteException.new('unknown message {"method"=>"prepare", "blah"=>"blah"}') }

            it 'tolerates the error since prepare message is an optimization and old agents might not know it' do
              expect { preparer.prepare }.not_to raise_error
            end
          end
        end

        context "when state of the instance is 'detached'" do
          before { allow(instance).to receive(:state).with(no_args).and_return('detached') }
          it_does_not_send_prepare
        end
      end

      context "when instance's resource pool has changed" do
        before { allow(instance).to receive(:resource_pool_changed?).with(no_args).and_return(true) }

        context "when state of the instance is not 'detached'" do
          before { allow(instance).to receive(:state).with(no_args).and_return('not-detached') }
          it_does_not_send_prepare
        end

        context "when state of the instance is 'detached'" do
          before { allow(instance).to receive(:state).with(no_args).and_return('detached') }
          it_does_not_send_prepare
        end
      end
    end
  end
end
