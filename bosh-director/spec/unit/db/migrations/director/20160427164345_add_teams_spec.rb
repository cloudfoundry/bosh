require 'db_spec_helper'

module Bosh::Director
  describe 'add_teams' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20160427164345_add_teams.rb' }

    before { DBSpecHelper.migrate_all_before(migration_file) }

    it 'migrates deployment teams over to Teams table' do
      db[:deployments] << {id: 1, name: 'deployment_with_teams', teams: 'prod,the-best'}
      db[:deployments] << {id: 2, name: 'other_deployment_with_teams', teams: 'prod,aspiring'}

      DBSpecHelper.migrate(migration_file)

      teams = db[:teams].all
      expect(teams.count).to eq(3)
      expect(teams.map{|i| i[:name]}.sort).to eq(['aspiring','prod','the-best'])
    end

    it 'preserves the teams associated with a deployment using a many-to-many table' do
      db[:deployments] << {id: 1, name: 'deployment_with_teams', teams: 'prod,the-best'}
      db[:deployments] << {id: 2, name: 'other_deployment_with_teams', teams: 'prod,aspiring'}

      DBSpecHelper.migrate(migration_file)

      deployments_teams = db[:deployments_teams].all
      expect(deployments_teams.count).to eq(4)
      expect(deployments_teams.select{|i| i[:deployment_id] == 1}.map{|i| i[:team_id]}.sort).to eq([1,2])
      expect(deployments_teams.select{|i| i[:deployment_id] == 2}.map{|i| i[:team_id]}.sort).to eq([1,3])
    end

    it 'should check that deployments_teams has unique deployment_id and team_id pairs' do
      db[:deployments] << {id: 1, name: 'deployment_with_teams', teams: 'prod,the-best'}

      DBSpecHelper.migrate(migration_file)

      expect {
        db[:deployments_teams] << {deployment_id: 1, team_id: 2}
      }.to raise_error Sequel::UniqueConstraintViolation
    end

    it 'removes the teams column from deployment' do
      db[:deployments] << {id: 1, name: 'deployment_with_teams', teams: 'prod,the-best'}
      db[:deployments] << {id: 2, name: 'other_deployment_with_teams', teams: 'prod,aspiring'}
      db[:deployments] << {id: 3, name: 'deployment_without_teams'}

      DBSpecHelper.migrate(migration_file)

      deployments = db[:deployments].all
      deployment_fields = deployments.map(&:keys).uniq.flatten
      expect(deployments.count).to eq(3)
      expect(deployment_fields).to eq([:id, :name, :manifest, :cloud_config_id, :link_spec_json, :runtime_config_id])
    end

    it 'removes the teams column from tasks' do
      db[:tasks] << {id: 1, state: 'alabama', timestamp: '2016-04-14 11:53:42', description: 'descr', type: 'type', teams: 'prod,the-best' }
      db[:tasks] << {id: 2, state: 'alabama', timestamp: '2016-04-14 11:53:42', description: 'descr', type: 'type',teams: 'prod,aspiring' }
      db[:tasks] << {id: 3, state: 'alabama', timestamp: '2016-04-14 11:53:42', description: 'descr', type: 'type',}

      DBSpecHelper.migrate(migration_file)

      tasks = db[:tasks].all
      tasks_fields = tasks.map(&:keys).uniq.flatten
      expect(tasks.count).to eq(3)
      expect(tasks_fields).to eq([:id, :state, :timestamp, :description, :result, :output, :checkpoint_time, :type, :username, :deployment_name, :started_at])
    end

    it 'removes the teams column from tasks' do
      db[:tasks] << {id: 1, state: 'alabama', timestamp: '2016-04-14 11:53:42', description: 'descr', type: 'type', teams: 'prod,the-best' }
      db[:tasks] << {id: 2, state: 'alabama', timestamp: '2016-04-14 11:53:42', description: 'descr', type: 'type',teams: 'prod,aspiring' }
      db[:tasks] << {id: 3, state: 'alabama', timestamp: '2016-04-14 11:53:42', description: 'descr', type: 'type',}

      DBSpecHelper.migrate(migration_file)

      tasks = db[:tasks].all
      tasks_fields = tasks.map(&:keys).uniq.flatten
      expect(tasks.count).to eq(3)
      expect(tasks_fields).to eq([:id, :state, :timestamp, :description, :result, :output, :checkpoint_time, :type, :username, :deployment_name, :started_at])
    end
  end
end
