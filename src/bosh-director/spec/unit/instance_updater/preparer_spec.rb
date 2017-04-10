require 'spec_helper'

module Bosh::Director
  describe InstanceUpdater::Preparer do
    subject(:preparer) { described_class.new(instance_plan, agent_client, logger) }
    let(:instance) do
      instance_double(
        'Bosh::Director::DeploymentPlan::Instance',
        deployment_model: Models::Deployment.make,
        rendered_templates_archive: nil,
        configuration_hash: {'fake-spec' => true},
        template_hashes: []
      )
    end
    let(:instance_plan) do
      job = DeploymentPlan::InstanceGroup.new(logger)
      Bosh::Director::DeploymentPlan::InstancePlan.new(
        desired_instance: DeploymentPlan::DesiredInstance.new(job),
        existing_instance: nil,
        instance: instance,
        needs_recreate?: false
      )
    end
    let(:agent_client) { instance_double('Bosh::Director::AgentClient') }

    before do
      fake_app
    end

    describe '#prepare' do
      def self.it_does_not_send_prepare
        it 'does not send prepare message to the instance' do
          expect(agent_client).not_to receive(:prepare)
          preparer.prepare
        end
      end
      before do
        allow(instance_plan).to receive(:needs_shutting_down?).with(no_args).and_return(false)
      end

      context 'when nothing has changed' do
        context "when state of the instance is not 'detached'" do
          before { allow(instance).to receive(:state).with(no_args).and_return('not-detached') }
          before do
            expected_instance_spec = DeploymentPlan::InstanceSpec.new(apply_spec, instance)
            allow(DeploymentPlan::InstanceSpec).to receive(:create_from_instance_plan).with(instance_plan).and_return(expected_instance_spec)
          end
          let(:apply_spec) do
            {'template_hashes' =>[], 'configuration_hash' =>{'fake-spec' =>true}}
          end

          context 'when instance does not need to be recreated' do
            before { allow(instance_plan).to receive_messages(needs_recreate?: false) }

            it 'sends prepare message to the instance' do
              expect(agent_client).to receive(:prepare).with(apply_spec)
              preparer.prepare
            end
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

        context 'when instance needs to be shut down' do
          before { allow(instance_plan).to receive_messages(needs_shutting_down?: true) }
          it_does_not_send_prepare
        end
      end
    end
  end
end
