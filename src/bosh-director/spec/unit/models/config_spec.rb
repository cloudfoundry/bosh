require 'spec_helper'

module Bosh::Director::Models
  describe Config do
    let(:config_model) { Config.make(content: "---\n{key : value}") }

    describe '#raw_manifest' do
      it 'returns raw content as parsed yaml' do
        expect(config_model.name).to eq('some-name')
        expect(config_model.raw_manifest.fetch('key')).to eq('value')
      end
    end

    describe '#raw_manifest=' do
      it 'returns updated content' do
        config_model.raw_manifest = { 'key' => 'value2' }
        expect(config_model.raw_manifest.fetch('key')).to eq('value2')
      end
    end

    describe '#latest_set' do
      it 'returns the latest default config of the given type' do
        Bosh::Director::Models::Config.new(type: 'expected_type', content: 'fake_content', name: 'default').save
        Bosh::Director::Models::Config.new(type: 'expected_type', content: 'fake_content', name: 'default').save
        expected = Bosh::Director::Models::Config.new(type: 'expected_type', content: 'fake_content', name: 'default').save
        Bosh::Director::Models::Config.new(type: 'unexpected_type', content: 'fake_content', name: 'default').save

        latests = Bosh::Director::Models::Config.latest_set('expected_type')
        expect(latests).to contain_exactly(expected)
      end

      it 'returns the latest configs of a given type grouped by name' do
        Bosh::Director::Models::Config.new(type: 'expected_type', content: 'fake_content', name: 'fake_name_1').save
        expected1 = Bosh::Director::Models::Config.new(type: 'expected_type', content: 'fake_content', name: 'fake_name_1').save
        expected2 = Bosh::Director::Models::Config.new(type: 'expected_type', content: 'fake_content', name: 'fake_name_2').save
        Bosh::Director::Models::Config.new(type: 'unexpected_type', content: 'fake_content', name: 'fake_name_3').save

        latests = Bosh::Director::Models::Config.latest_set('expected_type')
        expect(latests).to contain_exactly(expected1, expected2)
      end

      it 'returns empty list when there are no records' do
        expect(Bosh::Director::Models::Config.latest_set('type')).to be_empty
      end

      context 'deleted config name' do
        it 'is not enumerated in latest' do
          Bosh::Director::Models::Config.new(type: 'fake-cloud', content: 'v1', name: 'one').save
          one2 = Bosh::Director::Models::Config.new(type: 'fake-cloud', content: 'v2', name: 'one').save

          Bosh::Director::Models::Config.new(type: 'fake-cloud', content: 'v1', name: 'two').save
          Bosh::Director::Models::Config.new(type: 'fake-cloud', content: 'v2', name: 'two', deleted: true).save

          latests = Bosh::Director::Models::Config.latest_set('fake-cloud')
          expect(latests).to contain_exactly(one2)
        end

        context 'resurrected a named config' do
          it 'is enumerated in latest' do
            Bosh::Director::Models::Config.new(type: 'fake-cloud', content: 'v1', name: 'one').save
            one2 = Bosh::Director::Models::Config.new(type: 'fake-cloud', content: 'v2', name: 'one').save

            Bosh::Director::Models::Config.new(type: 'fake-cloud', content: 'v1', name: 'two').save
            Bosh::Director::Models::Config.new(type: 'fake-cloud', content: 'v2', name: 'two', deleted: true).save
            two3 = Bosh::Director::Models::Config.new(type: 'fake-cloud', content: 'v3', name: 'two').save

            latests = Bosh::Director::Models::Config.latest_set('fake-cloud')
            expect(latests).to contain_exactly(one2, two3)
          end
        end
      end
    end

    describe '#find_by_ids' do
      it 'returns all records that match ids' do
        configs = [
          Bosh::Director::Models::Config.new(type: 'expected_type', content: 'fake_content', name: 'default').save,
          Bosh::Director::Models::Config.new(type: 'expected_type', content: 'fake_content', name: 'default').save,
          Bosh::Director::Models::Config.new(type: 'expected_type', content: 'fake_content', name: 'default').save,
        ]

        expect(Bosh::Director::Models::Config.find_by_ids(configs.map(&:id))).to match_array(configs)
      end

      it 'returns empty array when passed nil' do
        expect(Bosh::Director::Models::Config.find_by_ids(nil)).to eq([])
      end
    end

    describe '#current?' do
      let!(:config1) { Config.make(type: 'cloud', name: 'bob') }
      let!(:config2) { Config.make(type: 'cloud', name: 'bob') }
      let!(:config3) { Config.make(type: 'cloud', name: 'bob', deleted: true) }

      it 'knows whether it is the highest-id config for its type and name' do
        expect(config1.current?).to be false
        expect(config2.current?).to be true
        expect(config3.current?).to be false
      end
    end

    describe '#to_hash' do
      let(:red_team) { Team.make(name: 'red') }
      let(:red_team_cloud_config) do
        Config.make(type: 'cloud', name: 'red-cloud-config', team_id: red_team.id, content: 'foo')
      end

      it 'serializes to a hash' do
        expect(red_team_cloud_config.to_hash).to match(
          content: 'foo',
          id: red_team_cloud_config.id.to_s,
          type: 'cloud',
          name: 'red-cloud-config',
          created_at: anything,
          team: 'red',
          current: true,
        )
      end
    end

    describe '#latest_set_for_teams' do
      let!(:red_team) { Bosh::Director::Models::Team.make(name: 'red') }
      let!(:blue_team) { Bosh::Director::Models::Team.make(name: 'blue') }
      let!(:global_cloud_config) { Bosh::Director::Models::Config.make(type: 'cloud', name: 'default') }
      let!(:global_runtime_config) { Bosh::Director::Models::Config.make(type: 'runtime', name: 'default') }
      let!(:red_team_cloud_config) { Bosh::Director::Models::Config.make(type: 'cloud', name: 'red-cloud-config', team_id: red_team.id) }
      let!(:red_team_cloud_config2) { Bosh::Director::Models::Config.make(type: 'cloud', name: 'red-cloud-config', team_id: red_team.id) }
      let!(:red_team_runtime_config) { Bosh::Director::Models::Config.make(type: 'runtime', name: 'red-runtime-config', team_id: red_team.id) }
      let!(:blue_team_cloud_config) { Bosh::Director::Models::Config.make(type: 'cloud', name: 'blue-config', team_id: blue_team.id) }
      let!(:blue_team_runtime_config) { Bosh::Director::Models::Config.make(type: 'runtime', name: 'blue-runtime-config', team_id: blue_team.id) }

      it 'returns team-specific configs for a given type grouped by name' do
        latest = Bosh::Director::Models::Config.latest_set_for_teams('cloud', red_team)
        expect(latest).to contain_exactly(global_cloud_config, red_team_cloud_config2)
      end

      it 'returns configs for all given teams for a given type grouped by name' do
        latest = Bosh::Director::Models::Config.latest_set_for_teams('cloud', red_team, blue_team)
        expect(latest).to contain_exactly(global_cloud_config, red_team_cloud_config2, blue_team_cloud_config)
      end

      it 'returns empty list when there are no records' do
        expect(Bosh::Director::Models::Config.latest_set_for_teams('none')).to be_empty
      end

      context 'deleted config name' do
        before do
          Bosh::Director::Models::Config.make(type: 'cloud', name: 'blue-config', team_id: blue_team.id, deleted: true)
        end

        it 'is not enumerated in latest' do
          latest = Bosh::Director::Models::Config.latest_set_for_teams('cloud', blue_team)
          expect(latest).to contain_exactly(global_cloud_config)
        end

        context 'resurrected a named config' do
          let!(:blue_team_cloud_config_resurrected) do
            Bosh::Director::Models::Config.make(type: 'cloud', name: 'blue-config', team_id: blue_team.id)
          end

          it 'is enumerated in latest' do
            latest = Bosh::Director::Models::Config.latest_set_for_teams('cloud', blue_team)
            expect(latest).to contain_exactly(global_cloud_config, blue_team_cloud_config_resurrected)
          end
        end
      end
    end

    describe '#find_by_ids_for_teams' do
      let!(:red_team) { Bosh::Director::Models::Team.make(name: 'red') }
      let!(:blue_team) { Bosh::Director::Models::Team.make(name: 'blue') }
      let!(:global_cloud_config) { Bosh::Director::Models::Config.make(type: 'cloud', name: 'default') }
      let!(:global_runtime_config) { Bosh::Director::Models::Config.make(type: 'runtime', name: 'default') }
      let!(:red_team_cloud_config) { Bosh::Director::Models::Config.make(type: 'cloud', name: 'red-cloud-config', team_id: red_team.id) }
      let!(:red_team_runtime_config) { Bosh::Director::Models::Config.make(type: 'runtime', name: 'red-runtime-config', team_id: red_team.id) }
      let!(:blue_team_cloud_config) { Bosh::Director::Models::Config.make(type: 'cloud', name: 'blue-config', team_id: blue_team.id) }
      let!(:blue_team_runtime_config) { Bosh::Director::Models::Config.make(type: 'runtime', name: 'blue-runtime-config', team_id: blue_team.id) }
      let!(:deleted_blue_team_runtime_config) { Bosh::Director::Models::Config.make(type: 'runtime', name: 'blue-runtime-config', team_id: blue_team.id, deleted: true) }

      it 'returns team-specific configs for given ids' do
        latest = Bosh::Director::Models::Config.find_by_ids_for_teams([global_cloud_config.id, red_team_cloud_config.id], red_team)
        expect(latest).to contain_exactly(global_cloud_config, red_team_cloud_config)
      end

      it 'returns configs for all given teams for given ids' do
        latest = Bosh::Director::Models::Config.find_by_ids_for_teams(
          [global_cloud_config.id, red_team_cloud_config.id, blue_team_cloud_config.id],
          red_team,
          blue_team,
        )
        expect(latest).to contain_exactly(global_cloud_config, red_team_cloud_config, blue_team_cloud_config)
      end

      it 'returns empty set of configs when given nil id' do
        latest = Bosh::Director::Models::Config.find_by_ids_for_teams(
          nil,
          red_team,
          blue_team,
        )
        expect(latest).to be_empty
      end

      it 'returns empty set of configs when given empty set of ids' do
        latest = Bosh::Director::Models::Config.find_by_ids_for_teams(
          [],
          red_team,
          blue_team,
        )
        expect(latest).to be_empty
      end

      it 'errors if any of given ids does not belong to teams' do
        expect do
          Bosh::Director::Models::Config.find_by_ids_for_teams(
            [global_cloud_config.id, red_team_cloud_config.id, blue_team_runtime_config.id],
            red_team,
          )
        end.to raise_error(Sequel::NoMatchingRow, /Failed to find ID: #{blue_team_runtime_config.id}/)
      end
    end

    describe '#team' do
      it 'returns teams array' do
        team = Team.create(name: 'dev')
        Config.new(type: 'fake-cloud', content: 'v1', name: 'one', team_id: team.id).save
        expect(Config.first.team).to eq(team)
      end

      it 'returns nil when no team_id' do
        Bosh::Director::Models::Config.new(type: 'fake-cloud', content: 'v1', name: 'one').save
        expect(Bosh::Director::Models::Config.first.team).to be_nil
      end
    end
  end
end
