require 'spec_helper'
require 'bosh/director/models/deployment'

module Bosh::Director::Models
  describe Deployment do
    subject(:deployment) { described_class.make(manifest: manifest, name: 'dep1') }
    let(:db_is_mysql) { ENV['DB'] == 'mysql' }
    let(:deadlock_exception) { Sequel::DatabaseError.new('Mysql2::Error: Deadlock found when trying to get lock') }

    describe '#tags' do
      before { VariableSet.make(deployed_successfully: true, deployment: deployment) }

      context 'when manifest is nil' do
        let(:manifest) { nil }

        it 'returns empty list' do
          expect(deployment.tags).to eq({})
        end
      end

      context 'when manifest is not nil' do
        context 'when tags are present' do
          let(:mock_client) { instance_double(Bosh::Director::ConfigServer::ConfigServerClient) }
          let(:mock_client_factory) { double(Bosh::Director::ConfigServer::ClientFactory) }
          let(:tags) do
            {}
          end

          before do
            allow(Bosh::Director::ConfigServer::ClientFactory).to receive(:create).and_return(mock_client_factory)
            allow(mock_client_factory).to receive(:create_client).and_return(mock_client)
            allow(mock_client).to receive(:interpolate_with_versioning).and_return(interpolated_tags)
          end

          context 'when tags do NOT use variables' do
            let(:manifest) do
              %(---
                tags:
                  tag1: value1
                  tag2: value2
              )
            end

            let(:interpolated_tags) do
              {
                'tag1' => 'value1',
                'tag2' => 'value2',
              }
            end

            it 'returns the tags in deployment manifest' do
              expect(deployment.tags).to eq(
                'tag1' => 'value1',
                'tag2' => 'value2',
              )
            end
          end

          context 'when tags use variables' do
            let(:manifest) do
              %(---
                tags:
                  tagA: ((tag-var1))
                  tagO: ((/tag-var2))
              )
            end

            let(:tags) do
              {
                'tagA' => '((tag-var1))',
                'tagO' => '((/tag-var2))',
              }
            end

            let(:interpolated_tags) do
              {
                'tagA' => 'apples',
                'tagO' => 'oranges',
              }
            end

            let(:options) { {} }

            before do
              allow(mock_client).to receive(:interpolate_with_versioning)
                .with(tags, anything, anything)
                .and_return(interpolated_tags)
            end

            it 'substitutes the variables in the tags section' do
              expect(mock_client).to receive(:interpolate_with_versioning)
                .with(tags, deployment.current_variable_set, options)
                .and_return(interpolated_tags)
              expect(deployment.tags).to eq(interpolated_tags)
            end

            context 'runtime configs provide tags' do
              before do
                runtime_config = Config.make(
                  type: 'runtime',
                  name: 'default',
                  content: '--- {releases: [], tags: {runtime-key: runtime-value}}',
                )
                deployment.add_runtime_config(runtime_config)
                allow(mock_client).to receive(:interpolate_with_versioning)
                  .with(runtime_config.raw_manifest, anything, anything)
                  .and_return(runtime_config.raw_manifest)
              end

              it 'includes runtime config tags' do
                expect(deployment.tags).to eq(
                  'tagA' => 'apples',
                  'tagO' => 'oranges',
                  'runtime-key' => 'runtime-value',
                )
              end
            end
          end
        end

        context 'when tags are NOT present' do
          let(:mock_client) { instance_double(Bosh::Director::ConfigServer::ConfigServerClient) }
          let(:mock_client_factory) { double(Bosh::Director::ConfigServer::ClientFactory) }
          let(:manifest) { '--- {}' }

          before do
            allow(Bosh::Director::ConfigServer::ClientFactory).to receive(:create).and_return(mock_client_factory)
            allow(mock_client_factory).to receive(:create_client).and_return(mock_client)
            allow(mock_client).to receive(:interpolate_with_versioning).and_return({})
          end

          it 'returns empty list' do
            expect(deployment.tags).to eq({})
          end

          context 'runtime configs provide tags' do
            before do
              runtime_config = Config.make(
                type: 'runtime',
                name: 'default',
                content: '--- {releases: [], tags: {runtime-key: runtime-value}}',
              )
              deployment.add_runtime_config(runtime_config)
              allow(mock_client).to receive(:interpolate_with_versioning)
                .with(runtime_config.raw_manifest, anything, anything)
                .and_return(runtime_config.raw_manifest)
            end

            it 'includes runtime config tags' do
              expect(deployment.tags).to eq(
                'runtime-key' => 'runtime-value',
              )
            end
          end
        end
      end
    end

    describe '#variables' do
      let(:deployment_1) { Deployment.make(manifest: 'test') }
      let(:deployment_2) { Deployment.make(manifest: 'vroom') }
      let(:deployment_3) { Deployment.make(manifest: 'hello') }
      let(:variable_set_1) { VariableSet.make(id: 1, deployment: deployment_1) }
      let(:variable_set_2) { VariableSet.make(id: 2, deployment: deployment_1) }
      let(:variable_set_3) { VariableSet.make(id: 12, deployment: deployment_2) }
      let(:variable_set_4) { VariableSet.make(id: 13, deployment: deployment_2) }

      it 'returns the variables associated with a deployment' do
        dep_1_variables = [
          Variable.make(id: 1, variable_id: 'var_id_1', variable_name: 'var_name_1', variable_set_id: variable_set_1.id),
          Variable.make(id: 2, variable_id: 'var_id_2', variable_name: 'var_name_2', variable_set_id: variable_set_1.id),
          Variable.make(id: 3, variable_id: 'var_id_3', variable_name: 'var_name_3', variable_set_id: variable_set_2.id)
        ]

        dep_2_variables = [
          Variable.make(id: 4, variable_id: 'var_id_1', variable_name: 'var_name_1', variable_set_id: variable_set_3.id),
          Variable.make(id: 5, variable_id: 'var_id_2', variable_name: 'var_name_2', variable_set_id: variable_set_3.id),
          Variable.make(id: 6, variable_id: 'var_id_3', variable_name: 'var_name_3', variable_set_id: variable_set_4.id),
          Variable.make(id: 7, variable_id: 'var_id_4', variable_name: 'var_name_4', variable_set_id: variable_set_4.id)
        ]

        expect(deployment_1.variables).to match_array(dep_1_variables)
        expect(deployment_2.variables).to match_array(dep_2_variables)
        expect(deployment_3.variables).to be_empty
      end
    end

    describe '#current_variable_set' do
      let(:deployment_1) { Deployment.make(manifest: 'test') }
      let(:deployment_2) { Deployment.make(manifest: 'vroom') }

      before do
        time = Time.now
        VariableSet.make(id: 1, deployment: deployment_1, created_at: time + 1)
        VariableSet.make(id: 2, deployment: deployment_1, created_at: time + 2)
        VariableSet.make(id: 3, deployment: deployment_1, created_at: time + 3)
      end

      it 'returns the deployment current variable set' do
        expect(deployment_1.current_variable_set.id).to eq(3)
        expect(deployment_2.current_variable_set).to be_nil
      end
    end

    describe '#last_successful_variable_set' do
      let(:deployment_1) { Deployment.make(manifest: 'test') }
      let(:deployment_2) { Deployment.make(manifest: 'vroom') }

      before do
        time = Time.now
        VariableSet.make(id: 1, deployment: deployment_1, created_at: time + 1, deployed_successfully: true)
        VariableSet.make(id: 2, deployment: deployment_1, created_at: time + 2, deployed_successfully: true)
        VariableSet.make(id: 3, deployment: deployment_1, created_at: time + 3, deployed_successfully: true)
        VariableSet.make(id: 4, deployment: deployment_1, created_at: time + 4, deployed_successfully: true)
        VariableSet.make(id: 5, deployment: deployment_1, created_at: time + 5, deployed_successfully: false)
        VariableSet.make(id: 6, deployment: deployment_1, created_at: time + 6, deployed_successfully: false)
      end

      it 'returns the deployment last successful variable set' do
        expect(deployment_1.last_successful_variable_set.id).to eq(4)
        expect(deployment_2.last_successful_variable_set).to be_nil
      end
    end

    describe '#previous_variable_set' do
      let(:deployment_1) { Deployment.make(manifest: 'test') }
      let(:deployment_2) { Deployment.make(manifest: 'vroom') }

      before do
        time = Time.now
        VariableSet.make(id: 1, deployment: deployment_1, created_at: time + 1, deployed_successfully: true)
        VariableSet.make(id: 2, deployment: deployment_1, created_at: time + 2, deployed_successfully: true)
        VariableSet.make(id: 3, deployment: deployment_1, created_at: time + 3, deployed_successfully: true)
        VariableSet.make(id: 4, deployment: deployment_1, created_at: time + 4, deployed_successfully: true)
        VariableSet.make(id: 5, deployment: deployment_1, created_at: time + 5, deployed_successfully: false)
        VariableSet.make(id: 6, deployment: deployment_1, created_at: time + 6, deployed_successfully: false)
      end

      it 'returns the deployment previous variable set, regardless of whether it was deployed_successfully' do
        expect(deployment_1.previous_variable_set.id).to eq(5)
        expect(deployment_2.previous_variable_set).to be_nil
      end
    end

    describe '#cleanup_variable_sets' do
      let(:deployment_1) { Deployment.make(manifest: 'test') }
      let(:deployment_2) { Deployment.make(manifest: 'vroom') }
      let(:time) { Time.now }

      it 'deletes variable sets not referenced in the list provided' do
        time = Time.now

        dep_1_variable_sets_to_keep = [
          VariableSet.make(id: 1, deployment: deployment_1, created_at: time + 1, deployed_successfully: true),
          VariableSet.make(id: 2, deployment: deployment_1, created_at: time + 2, deployed_successfully: true),
          VariableSet.make(id: 3, deployment: deployment_1, created_at: time + 3, deployed_successfully: true),
          VariableSet.make(id: 4, deployment: deployment_1, created_at: time + 4, deployed_successfully: true),
          VariableSet.make(id: 5, deployment: deployment_1, created_at: time + 5, deployed_successfully: false)
        ]

        dep_1_variable_sets_to_be_deleted = [
          VariableSet.make(id: 6, deployment: deployment_1, created_at: time + 6, deployed_successfully: true),
          VariableSet.make(id: 7, deployment: deployment_1, created_at: time + 7, deployed_successfully: true),
          VariableSet.make(id: 8, deployment: deployment_1, created_at: time + 8, deployed_successfully: true),
          VariableSet.make(id: 9, deployment: deployment_1, created_at: time + 9, deployed_successfully: false)
        ]

        dep_2_control_variable_sets = [
          VariableSet.make(id: 10, deployment: deployment_2, created_at: time + 10, deployed_successfully: false),
          VariableSet.make(id: 11, deployment: deployment_2, created_at: time + 11, deployed_successfully: true),
          VariableSet.make(id: 12, deployment: deployment_2, created_at: time + 12, deployed_successfully: false)
        ]

        expect(VariableSet.all).to match_array(dep_1_variable_sets_to_keep + dep_1_variable_sets_to_be_deleted + dep_2_control_variable_sets)

        deployment_1.cleanup_variable_sets(dep_1_variable_sets_to_keep)
        expect(VariableSet.all).to match_array(dep_1_variable_sets_to_keep + dep_2_control_variable_sets)

        deployment_2.cleanup_variable_sets(dep_2_control_variable_sets)
        expect(VariableSet.all).to match_array(dep_1_variable_sets_to_keep + dep_2_control_variable_sets)

        deployment_2.cleanup_variable_sets([])
        expect(VariableSet.all).to match_array(dep_1_variable_sets_to_keep)
      end
    end

    describe 'cloud_configs' do
      let(:manifest) { '---{}' }
      let(:cc1) { Bosh::Director::Models::Config.create(type: 'cloud', content: 'cc1-prop', name: 'cc1') }
      let(:cc2) { Bosh::Director::Models::Config.create(type: 'cloud', content: 'cc2-prop', name: 'cc2') }

      before do
        cc3 = Bosh::Director::Models::Config.create(type: 'cloud', content: 'cc3-prop', name: 'cc3')

        deployment.add_cloud_config(cc1)
        deployment.add_cloud_config(cc2)
        deployment.add_cloud_config(cc3)
      end

      it 'retries deadlocks' do
        expect(deployment).to receive(:remove_all_cloud_configs).and_raise(deadlock_exception).once
        expect(deployment).to receive(:remove_all_cloud_configs).and_call_original

        deployment.cloud_configs = [cc1, cc2]
        expect(deployment.cloud_configs).to eq([cc1, cc2])
      end

      it 'raises original deadlock exception on subsequent, non-retryable failures' do
        expect(deployment).to receive(:remove_all_cloud_configs).and_raise(deadlock_exception).once
        expect(deployment).to receive(:remove_all_cloud_configs).and_raise(Sequel::DatabaseError, 'fake foreign key constraint').once

        expect { deployment.cloud_configs = [cc1, cc2] }.to raise_error(deadlock_exception)
      end

      it '#add_cloud_config rejects adding other config types' do
        config = Bosh::Director::Models::Config.create(type: 'fake_type', content: 'fake_content', name: 'fake_name')
        expect {
          deployment.add_cloud_config(config)
        }.to raise_error Bosh::Director::ConfigTypeMismatch, "Expected config type 'cloud', but was 'fake_type'"
        expect( Bosh::Director::Config.db[:deployments_configs].map(:config_id)).to_not include(config.id)
      end

      it '#remove_cloud_config rejects removing other config types' do
        config = Bosh::Director::Models::Config.create(type: 'fake_type', content: 'fake_content', name: 'fake_name')
        Bosh::Director::Config.db[:deployments_configs].insert({deployment_id:deployment.id, config_id:config.id})
        expect {
          deployment.remove_cloud_config(config)
        }.to raise_error Bosh::Director::ConfigTypeMismatch, "Expected config type 'cloud', but was 'fake_type'"
        expect( Bosh::Director::Config.db[:deployments_configs].map(:config_id)).to include(config.id)
      end

      it "#remove_all_cloud_configs removes only configs associations of type 'cloud'" do
        config = Bosh::Director::Models::Config.create(type: 'fake_type', content: 'fake_content', name: 'fake_name')
        Bosh::Director::Config.db[:deployments_configs].insert({deployment_id:deployment.id, config_id:config.id})

        deployment.remove_all_cloud_configs

        expect(deployment.cloud_configs.size).to eq(0)
        expect( Bosh::Director::Config.db[:deployments_configs].count).to eq(1)
        expect( Bosh::Director::Config.db[:deployments_configs].map(:config_id)).to include(config.id)
        expect(Bosh::Director::Models::Config.where(type: 'fake_type').all.size).to eq 1
        expect(Bosh::Director::Models::Config.where(type: 'cloud').all.size).to eq 3
      end

      it '#cloud_configs= removes existing records & assigns the new cloud config records' do
        cc4 = Bosh::Director::Models::Config.create(type: 'cloud', content: 'cc4-prop', name: 'cc4')
        cc5 = Bosh::Director::Models::Config.create(type: 'cloud', content: 'cc5-prop', name: 'cc5')

        deployment.cloud_configs = [cc4, cc5]

        expect(Bosh::Director::Models::Deployment[id: deployment.id].cloud_configs).to contain_exactly(cc4, cc5)
      end

      it "#cloud_configs filters configs of type 'cloud'" do
        config = Bosh::Director::Models::Config.create(type: 'fake_type', content: 'fake_content', name: 'fake_name')
        Bosh::Director::Config.db[:deployments_configs].insert({deployment_id:deployment.id, config_id: config.id})

        expect(deployment.cloud_configs.size).to eq 3
        expect(deployment.cloud_configs).not_to include(config)
      end
    end

    describe 'runtime_configs' do
      let(:manifest) { '---{}' }
      let(:rc1) { Bosh::Director::Models::Config.create(type: 'runtime', content: 'rc1-prop', name: 'rc1') }

      before do
        rc2 = Bosh::Director::Models::Config.create(type: 'runtime', content: 'rc2-prop', name: 'rc2')
        rc3 = Bosh::Director::Models::Config.create(type: 'runtime', content: 'rc3-prop', name: 'rc3')

        deployment.add_runtime_config(rc1)
        deployment.add_runtime_config(rc2)
        deployment.add_runtime_config(rc3)
      end

      it 'retries deadlocks' do
        expect(deployment).to receive(:remove_all_runtime_configs).and_raise(deadlock_exception).once
        expect(deployment).to receive(:remove_all_runtime_configs).and_call_original

        deployment.runtime_configs = [rc1]
        expect(deployment.runtime_configs).to eq([rc1])
      end

      it 'raises original deadlock exception on subsequent, non-retryable failures' do
        expect(deployment).to receive(:remove_all_runtime_configs).and_raise(deadlock_exception).once
        expect(deployment).to receive(:remove_all_runtime_configs).and_raise(Sequel::DatabaseError, 'fake foreign key constraint').once

        expect { deployment.runtime_configs = [rc1] }.to raise_error(deadlock_exception)
      end

      it '#add_runtime_config rejects adding other config types' do
        config = Bosh::Director::Models::Config.create(type: 'fake_type', content: 'fake_content', name: 'fake_name')
        Bosh::Director::Config.db[:deployments_configs].insert({deployment_id:deployment.id, config_id:config.id})
        expect {
          deployment.add_runtime_config(config)
        }.to raise_error Bosh::Director::ConfigTypeMismatch, "Expected config type 'runtime', but was 'fake_type'"
        expect( Bosh::Director::Config.db[:deployments_configs].map(:config_id)).to include(config.id)

      end

      it '#remove_runtime_config rejects removing other config types' do
        config = Bosh::Director::Models::Config.create(type: 'fake_type', content: 'fake_content', name: 'fake_name')
        Bosh::Director::Config.db[:deployments_configs].insert({deployment_id:deployment.id, config_id:config.id})
        expect {
          deployment.remove_runtime_config(config)
        }.to raise_error Bosh::Director::ConfigTypeMismatch, "Expected config type 'runtime', but was 'fake_type'"

        expect( Bosh::Director::Config.db[:deployments_configs].map(:config_id)).to include(config.id)
      end

      it "#remove_all_runtime_configs removes only configs associations of type 'runtime'" do
        config = Bosh::Director::Models::Config.create(type: 'fake_type', content: 'fake_content', name: 'fake_name')
        Bosh::Director::Config.db[:deployments_configs].insert({deployment_id:deployment.id, config_id:config.id})

        deployment.remove_all_runtime_configs

        expect( Bosh::Director::Config.db[:deployments_configs].count).to eq(1)
        expect( Bosh::Director::Config.db[:deployments_configs].map(:config_id)).to include(config.id)

        expect(Bosh::Director::Models::Config.where(type: 'fake_type').all.size).to eq 1
        expect(Bosh::Director::Models::Config.where(type: 'runtime').all.size).to eq 3
      end

      it '#runtime_configs= removes existing records & assigns the new runtime config records' do
        rc4 = Bosh::Director::Models::Config.create(type: 'runtime', content: 'rc4-prop', name: 'rc4')
        rc5 = Bosh::Director::Models::Config.create(type: 'runtime', content: 'rc5-prop', name: 'rc5')

        deployment.runtime_configs = [rc4, rc5]

        expect(Bosh::Director::Models::Deployment[id: deployment.id].runtime_configs).to contain_exactly(rc4, rc5)
      end

      it "#runtime_configs filters configs of type 'runtime'" do
        config = Bosh::Director::Models::Config.create(type: 'fake_type', content: 'fake_content', name: 'fake_name')
        Bosh::Director::Config.db[:deployments_configs].insert({deployment_id:deployment.id, config_id:config.id})

        expect(deployment.runtime_configs.size).to eq 3
        expect(Bosh::Director::Models::Deployment[id: deployment.id].runtime_configs).not_to include(config)
      end
    end

    describe '#teams=' do
      let(:manifest) { nil }
      let(:team1) { Bosh::Director::Models::Team.create(name: 'team1') }

      it 'retries deadlocks' do
        expect(deployment).to receive(:remove_all_teams).and_raise(deadlock_exception).once
        expect(deployment).to receive(:remove_all_teams).and_call_original

        deployment.teams = [team1]
        expect(deployment.teams).to eq([team1])
      end

      it 'raises original deadlock exception on subsequent, non-retryable failures' do
        expect(deployment).to receive(:remove_all_teams).and_raise(deadlock_exception).once
        expect(deployment).to receive(:remove_all_teams).and_raise(Sequel::DatabaseError, 'fake foreign key constraint').once

        expect { deployment.teams = [team1] }.to raise_error(deadlock_exception)
      end
    end

    describe '#create_with_teams' do
      it 'saves attributes including teams & runtime_configs' do
        rc1 = Bosh::Director::Models::Config.create(type: 'runtime', content: 'rc1-prop', name: 'rc1')
        rc2 = Bosh::Director::Models::Config.create(type: 'runtime', content: 'rc2-prop', name: 'rc2')

        team1 = Bosh::Director::Models::Team.new(name: 'team1')
        team2 = Bosh::Director::Models::Team.new(name: 'team2')

        attr = {
          name: 'some-deploy',
          teams: [team1, team2],
          runtime_configs: [rc1, rc2],
        }

        deployment = Bosh::Director::Models::Deployment.create_with_teams(attr)

        saved_deployment = Bosh::Director::Models::Deployment[id: deployment.id]
        expect(saved_deployment).to eq(deployment)
        expect(saved_deployment.teams).to contain_exactly(team1, team2)
        expect(saved_deployment.runtime_configs).to contain_exactly(rc1, rc2)
      end
    end
  end
end
