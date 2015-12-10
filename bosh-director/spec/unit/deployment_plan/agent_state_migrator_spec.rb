require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::AgentStateMigrator do
    let(:agent_state_migrator) { described_class.new(deployment_plan, Config.logger) }
    let(:deployment_plan) { instance_double('Bosh::Director::DeploymentPlan::Planner', name: 'simple') }

    describe '#get_state' do
      it 'should return the processed agent state' do
        state = {'state' => 'baz'}

        vm_model = Models::Vm.make(:agent_id => 'agent-1')
        client = double('AgentClient')
        expect(AgentClient).to receive(:with_vm).with(vm_model).and_return(client)

        expect(client).to receive(:get_state).and_return(state)
        expect(agent_state_migrator).to receive(:verify_state).with(vm_model, state)
        expect(agent_state_migrator.get_state(vm_model)).to eq(state)
      end

      context 'when the returned state contains top level "release" key' do
        let(:agent_client) { double('AgentClient') }
        let(:vm_model) { Models::Vm.make(:agent_id => 'agent-1') }
        before { allow(AgentClient).to receive(:with_vm).with(vm_model).and_return(agent_client) }

        it 'prunes the legacy "release" data to avoid unnecessary update' do
          legacy_state = {'release' => 'cf', 'other' => 'data', 'job' => {}}
          final_state = {'other' => 'data', 'job' => {}}
          allow(agent_client).to receive(:get_state).and_return(legacy_state)

          allow(agent_state_migrator).to receive(:verify_state).with(vm_model, legacy_state)
          expect(agent_state_migrator.get_state(vm_model)).to eq(final_state)
        end

        context 'and the returned state contains a job level release' do
          it 'prunes the legacy "release" in job section so as to avoid unnecessary update' do
            legacy_state = {
              'release' => 'cf',
              'other' => 'data',
              'job' => {
                'release' => 'sql-release',
                'more' => 'data',
              },
            }
            final_state = {
              'other' => 'data',
              'job' => {
                'more' => 'data',
              },
            }
            allow(agent_client).to receive(:get_state).and_return(legacy_state)

            allow(agent_state_migrator).to receive(:verify_state).with(vm_model, legacy_state)
            allow(agent_state_migrator).to receive(:migrate_legacy_state).with(vm_model, legacy_state)

            expect(agent_state_migrator.get_state(vm_model)).to eq(final_state)
          end
        end

        context 'and the returned state does not contain a job level release' do
          it 'returns the job section as-is' do
            legacy_state = {
              'release' => 'cf',
              'other' => 'data',
              'job' => {
                'more' => 'data',
              },
            }
            final_state = {
              'other' => 'data',
              'job' => {
                'more' => 'data',
              },
            }
            allow(agent_client).to receive(:get_state).and_return(legacy_state)

            allow(agent_state_migrator).to receive(:verify_state).with(vm_model, legacy_state)
            allow(agent_state_migrator).to receive(:migrate_legacy_state).with(vm_model, legacy_state)

            expect(agent_state_migrator.get_state(vm_model)).to eq(final_state)
          end
        end
      end

      context 'when the returned state does not contain top level "release" key' do
        let(:agent_client) { double('AgentClient') }
        let(:vm_model) { Models::Vm.make(:agent_id => 'agent-1') }
        before do
          allow(AgentClient).to receive(:with_vm).with(vm_model).and_return(agent_client)
        end

        context 'and the returned state contains a job level release' do
          it 'prunes the legacy "release" in job section so as to avoid unnecessary update' do
            legacy_state = {
              'other' => 'data',
              'job' => {
                'release' => 'sql-release',
                'more' => 'data',
              },
            }
            final_state = {
              'other' => 'data',
              'job' => {
                'more' => 'data',
              },
            }
            allow(agent_client).to receive(:get_state).and_return(legacy_state)

            allow(agent_state_migrator).to receive(:verify_state).with(vm_model, legacy_state)
            allow(agent_state_migrator).to receive(:migrate_legacy_state).with(vm_model, legacy_state)

            expect(agent_state_migrator.get_state(vm_model)).to eq(final_state)
          end
        end

        context 'and the returned state does not contain a job level release' do
          it 'returns the job section as-is' do
            legacy_state = {
              'release' => 'cf',
              'other' => 'data',
              'job' => {
                'more' => 'data',
              },
            }
            final_state = {
              'other' => 'data',
              'job' => {
                'more' => 'data',
              },
            }
            allow(agent_client).to receive(:get_state).and_return(legacy_state)

            allow(agent_state_migrator).to receive(:verify_state).with(vm_model, legacy_state)
            allow(agent_state_migrator).to receive(:migrate_legacy_state).with(vm_model, legacy_state)

            expect(agent_state_migrator.get_state(vm_model)).to eq(final_state)
          end
        end
      end
    end

    describe '#verify_state' do
      before do
        @deployment = Models::Deployment.make(:name => 'foo')
        @vm_model = Models::Vm.make(:deployment => @deployment, :cid => 'foo')
        allow(deployment_plan).to receive(:name).and_return('foo')
        allow(deployment_plan).to receive(:model).and_return(@deployment)
      end

      it 'should do nothing when VM is ok' do
        agent_state_migrator.verify_state(@vm_model, {'deployment' => 'foo'})
      end

      it 'should do nothing when instance is ok' do
        Models::Instance.make(
          :deployment => @deployment, :vm => @vm_model, :job => 'bar', :index => 11)
        agent_state_migrator.verify_state(@vm_model, {
            'deployment' => 'foo',
            'job' => {
              'name' => 'bar'
            },
            'index' => 11
          })
      end

      it 'should make sure the state is a Hash' do
        expect {
          agent_state_migrator.verify_state(@vm_model, 'state')
        }.to raise_error(AgentInvalidStateFormat, /expected Hash/)
      end
    end
  end
end
