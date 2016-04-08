require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::AgentStateMigrator do
    let(:agent_state_migrator) { described_class.new(deployment_plan, Config.logger) }
    let(:deployment_plan) { instance_double('Bosh::Director::DeploymentPlan::Planner', name: 'simple') }
    let(:client) { instance_double(AgentClient) }
    let(:credentials) { Bosh::Core::EncryptionHandler.generate_credentials }

    let(:instance_model) { Models::Instance.make(credentials: credentials, agent_id: 'agent-1')}

    describe '#get_state' do
      before do
        expect(AgentClient).to receive(:with_vm_credentials_and_agent_id).with(credentials, 'agent-1').and_return(client)
      end

      it 'should return the processed agent state' do
        state = {'state' => 'baz'}

        expect(client).to receive(:get_state).and_return(state)
        expect(agent_state_migrator).to receive(:verify_state).with(instance_model, state)
        expect(agent_state_migrator.get_state(instance_model)).to eq(state)
      end

      context 'when the returned state contains top level "release" key' do
        it 'prunes the legacy "release" data to avoid unnecessary update' do
          legacy_state = {'release' => 'cf', 'other' => 'data', 'job' => {}}
          final_state = {'other' => 'data', 'job' => {}}
          allow(client).to receive(:get_state).and_return(legacy_state)

          allow(agent_state_migrator).to receive(:verify_state).with(instance_model, legacy_state)
          expect(agent_state_migrator.get_state(instance_model)).to eq(final_state)
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
            allow(client).to receive(:get_state).and_return(legacy_state)

            allow(agent_state_migrator).to receive(:verify_state).with(instance_model, legacy_state)
            allow(agent_state_migrator).to receive(:migrate_legacy_state).with(instance_model, legacy_state)

            expect(agent_state_migrator.get_state(instance_model)).to eq(final_state)
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
            allow(client).to receive(:get_state).and_return(legacy_state)

            allow(agent_state_migrator).to receive(:verify_state).with(instance_model, legacy_state)
            allow(agent_state_migrator).to receive(:migrate_legacy_state).with(instance_model, legacy_state)

            expect(agent_state_migrator.get_state(instance_model)).to eq(final_state)
          end
        end
      end

      context 'when the returned state does not contain top level "release" key' do
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
            allow(client).to receive(:get_state).and_return(legacy_state)

            allow(agent_state_migrator).to receive(:verify_state).with(instance_model, legacy_state)
            allow(agent_state_migrator).to receive(:migrate_legacy_state).with(instance_model, legacy_state)

            expect(agent_state_migrator.get_state(instance_model)).to eq(final_state)
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
            allow(client).to receive(:get_state).and_return(legacy_state)

            allow(agent_state_migrator).to receive(:verify_state).with(instance_model, legacy_state)
            allow(agent_state_migrator).to receive(:migrate_legacy_state).with(instance_model, legacy_state)

            expect(agent_state_migrator.get_state(instance_model)).to eq(final_state)
          end
        end
      end
    end

    describe '#verify_state' do
      before do
        @deployment = Models::Deployment.make(:name => 'foo')
        allow(deployment_plan).to receive(:name).and_return('foo')
        allow(deployment_plan).to receive(:model).and_return(@deployment)
      end

      it 'should do nothing when VM is ok' do
        agent_state_migrator.verify_state(instance_model, {'deployment' => 'foo'})
      end

      it 'should do nothing when instance is ok' do
        Models::Instance.make(
          :deployment => @deployment, :vm_cid => 'foo-vm', :job => 'bar', :index => 11)
        agent_state_migrator.verify_state(instance_model, {
            'deployment' => 'foo',
            'job' => {
              'name' => 'bar'
            },
            'index' => 11
          })
      end

      it 'should make sure the state is a Hash' do
        expect {
          agent_state_migrator.verify_state(instance_model, 'state')
        }.to raise_error(AgentInvalidStateFormat, /expected Hash/)
      end
    end
  end
end
