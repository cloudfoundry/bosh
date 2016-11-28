Sequel.migration do
  up do
    create_table :teams do
      primary_key :id
      String :name, :unique => true, :null => false
    end

    create_table :deployments_teams do
      foreign_key :deployment_id, :deployments, :null => false, :on_delete => :cascade
      foreign_key :team_id, :teams, :null => false, :on_delete => :cascade
      unique [:deployment_id, :team_id]
    end

    deployments_with_teams = self[:deployments].reject { |d| d[:teams].nil? }
    team_names = deployments_with_teams
                   .map { |d| d[:teams].split(',') }
                   .flatten
                   .uniq
                   .map { |team| [team] }

    self[:teams].import([:name], team_names)

    deployments_with_teams.each do |d|
      deployment_teams = d[:teams]
                           .split(',')
                           .map do |team_name|
        team = self[:teams].filter({name: team_name}).first
        [d[:id], team[:id]]
      end

      self[:deployments_teams].import([:deployment_id, :team_id], deployment_teams)
    end

    alter_table(:deployments) do
      drop_column :teams
    end

    create_table :tasks_teams do
      foreign_key :task_id, :tasks, :null => false, :on_delete => :cascade
      foreign_key :team_id, :teams, :null => false, :on_delete => :cascade
      unique [:task_id, :team_id]
    end

    alter_table(:tasks) do
      drop_column :teams
    end
  end
end
