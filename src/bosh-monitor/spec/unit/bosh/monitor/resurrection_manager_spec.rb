require_relative '../../../spec_helper'

module Bhm
  describe ResurrectionManager do
    let(:manager) { described_class.new }

    let(:include_spec) do
      {
        'deployments' => ['deployment_include'],
        'instance_groups' => ['foobar-1'],
      }
    end
    let(:exclude_spec) { { 'deployments' => ['deployment_exclude'] } }

    let(:resurrection_config) do
      [
        {
          'content' => YAML.dump(resurrection_config_content),
          'id' => '1', 'type' => 'resurrection',
          'name' => 'some-name'
        },
      ]
    end

    let(:resurrection_configs) do
      [
        { 'content' => YAML.dump(resurrection_config_content), 'id' => '1', 'type' => 'resurrection', 'name' => 'some-name' },
        { 'content' => YAML.dump(resurrection_config_content), 'id' => '2', 'type' => 'resurrection', 'name' => 'another-name' },
      ]
    end

    before do
      Bhm.config = { 'director' => {} }
      Bhm.plugins = [{ 'name' => 'logger' }, { 'name' => 'logger' }]
    end

    describe '#update_rules' do
      let(:resurrection_config_content) do
        {
          'rules' => [
            {
              'enabled' => true,
              'include' => include_spec,
            },
            {
              'enabled' => false,
              'exclude' => exclude_spec,
            },
          ],
        }
      end

      it 'parses resurrection config' do
        expect(logger).to receive(:info).with('Resurrection config update starting...')
        expect(logger).to receive(:info).with('Resurrection config update finished')
        manager.update_rules(resurrection_config)
        resurrection_rules = manager.instance_variable_get(:@parsed_rules)
        expect(resurrection_rules.count).to eq(2)
        expect(resurrection_rules[0].enabled?).to be_truthy
        expect(resurrection_rules[1].enabled?).to be_falsey
      end

      it 'parses several resurrection configs with different names' do
        expect(logger).to receive(:info).with('Resurrection config update starting...')
        expect(logger).to receive(:info).with('Resurrection config update finished')
        manager.update_rules(resurrection_configs)
        resurrection_rules = manager.instance_variable_get(:@parsed_rules)
        expect(resurrection_rules.count).to eq(4)
        expect(resurrection_rules[0].enabled?).to be_truthy
        expect(resurrection_rules[1].enabled?).to be_falsey
        expect(resurrection_rules[2].enabled?).to be_truthy
        expect(resurrection_rules[3].enabled?).to be_falsey
      end

      context 'when resurrection config does not have enabled property' do
        let(:resurrection_config_content) do
          {
            'rules' => [
              {
                'include' => { 'deployments' => ['deployment_include'] },
              },
            ],
          }
        end

        it 'returns an error' do
          expect(logger).to receive(:error)
            .with(/Required property 'enabled' was not specified in object>/)
          manager.update_rules(resurrection_config)
        end
      end

      context 'when enabled property is not boolean' do
        let(:resurrection_config_content) do
          {
            'rules' => [
              { 'enabled' => 5,
                'include' => { 'deployments' => ['deployment_include'] } },
            ],
          }
        end

        it 'returns an error' do
          expect(logger).to receive(:error)
            .with(/Property 'enabled' value \(5\) did not match the required type 'Boolean'/)
          manager.update_rules(resurrection_config)
        end
      end

      context 'when resurrection config was not updated' do
        it 'uses existing resurrection rules' do
          manager.update_rules(resurrection_config)
          expect(logger).not_to receive(:info).with('Resurrection config update starting...')
          expect(logger).to receive(:info).with('Resurrection config remains the same')
          manager.update_rules(resurrection_config)
          resurrection_rules = manager.instance_variable_get(:@parsed_rules)
          expect(resurrection_rules.count).to eq(2)
          expect(resurrection_rules[0].enabled?).to be_truthy
          expect(resurrection_rules[1].enabled?).to be_falsey
        end
      end

      context 'when resurrection config is an empty array' do
        it 'deletes existing resurrection rules' do
          manager.update_rules(resurrection_config)
          expect(logger).to receive(:info).with('Resurrection config update starting...')
          expect(logger).to receive(:info).with('Resurrection config update finished')
          manager.update_rules([])
          resurrection_rules = manager.instance_variable_get(:@parsed_rules)
          expect(resurrection_rules.count).to eq(0)
        end
      end

      context 'when resurrection config is nil' do
        it 'uses existing resurrection rules' do
          expect(logger).to receive(:info).with('Resurrection config update starting...')
          expect(logger).to receive(:info).with('Resurrection config update finished')
          manager.update_rules(resurrection_config)

          manager.update_rules(nil)
          resurrection_rules = manager.instance_variable_get(:@parsed_rules)
          expect(resurrection_rules.count).to eq(2)
          expect(resurrection_rules[0].enabled?).to be_truthy
          expect(resurrection_rules[1].enabled?).to be_falsey
        end
      end
    end

    describe '#resurrection_enabled?' do
      let(:resurrection_config_content) do
        {
          'rules' => [
            {
              'enabled' => enabled,
              'include' => include_spec,
              'exclude' => exclude_spec,
            },
          ],
        }
      end
      let(:exclude_spec) { {} }
      before { manager.update_rules(resurrection_config) }

      context 'when `enabled` equals true' do
        let(:enabled) { true }

        context 'when the resurrection config is applicable by deployment name' do
          let(:include_spec) { { 'deployments' => ['deployment_include'] } }
          it 'sends to resurrection' do
            expect(manager.resurrection_enabled?('deployment_include', 'foobar')).to be_truthy
          end
        end

        context 'when the deployment is neither included nor excluded' do
          let(:include_spec) { { 'deployments' => ['no_findy'] } }

          it 'sends to resurrection' do
            expect(manager.resurrection_enabled?('deployment_include', 'foobar')).to be_truthy
          end
        end

        context 'when the resurrection config is applicable by instance group' do
          let(:include_spec) { { 'instance_groups' => ['foobar'] } }

          it 'sends to resurrection' do
            expect(manager.resurrection_enabled?('deployment_include', 'foobar')).to be_truthy
          end
        end

        context 'when the instance group is neither included nor excluded' do
          let(:include_spec) { { 'instance_groups' => ['no_findy'] } }

          it 'sends to resurrection' do
            expect(manager.resurrection_enabled?('deployment_include', 'foobar')).to be_truthy
          end
        end

        context 'when the resurrection config has empty include and exclude' do
          let(:include_spec) { {} }
          let(:exclude_spec) { {} }

          it 'sends to resurrection' do
            expect(manager.resurrection_enabled?('deployment_include', 'foobar')).to be_truthy
          end
        end

        context 'when the resurrection config has the same include and exclude ' do
          let(:include_spec) { { 'deployments' => ['deployment_include'] } }
          let(:exclude_spec) { { 'deployments' => ['deployment_include'] } }

          it 'sends to resurrection' do
            expect(manager.resurrection_enabled?('deployment_include', 'foobar')).to be_truthy
          end
        end
      end

      context 'when `enabled` equals false' do
        let(:enabled) { false }

        context 'when the resurrection config is applicable by deployment name' do
          let(:include_spec) { { 'deployments' => ['deployment_include'] } }

          it 'does not send to resurrection' do
            expect(manager.resurrection_enabled?('deployment_include', 'foobar')).to be_falsey
          end
        end

        context 'when the deployment is neither included nor excluded' do
          let(:include_spec) { { 'deployments' => ['no_findy'] } }

          it 'sends to resurrection' do
            expect(manager.resurrection_enabled?('deployment_include', 'foobar')).to be_truthy
          end
        end

        context 'when the resurrection config is applicable by instance group' do
          let(:include_spec) { { 'instance_groups' => ['foobar'] } }

          it 'does not send to resurrection' do
            expect(manager.resurrection_enabled?('deployment_include', 'foobar')).to be_falsey
          end
        end

        context 'when the instance group is neither included nor excluded' do
          let(:include_spec) { { 'instance_groups' => ['no_findy'] } }

          it 'sends to resurrection' do
            expect(manager.resurrection_enabled?('deployment_include', 'foobar')).to be_truthy
          end
        end

        context 'when the resurrection config has empty include and exclude' do
          let(:include_spec) { {} }
          let(:exclude_spec) { {} }

          it 'does not send to resurrection' do
            expect(manager.resurrection_enabled?('deployment_include', 'foobar')).to be_falsey
          end
        end

        context 'when the resurrection config has the same include and exclude ' do
          let(:include_spec) { { 'deployments' => ['deployment_include'] } }
          let(:exclude_spec) { { 'deployments' => ['deployment_include'] } }

          it 'sends to resurrection' do
            expect(manager.resurrection_enabled?('deployment_include', 'foobar')).to be_truthy
          end
        end
      end

      context 'when several rules are applied' do
        let(:resurrection_config_content) do
          {
            'rules' => [
              {
                'enabled' => true,
                'include' => { 'deployments' => ['deployment_include'] },
              },
              {
                'enabled' => false,
                'include' => { 'deployments' => ['deployment_include'] },
              },
            ],
          }
        end

        it 'does not send to resurrection' do
          expect(manager.resurrection_enabled?('deployment_include', 'foobar')).to be_falsey
        end
      end
    end
  end
end
