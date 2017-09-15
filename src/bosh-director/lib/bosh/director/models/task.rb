module Bosh::Director::Models
  class Task < Sequel::Model(Bosh::Director::Config.db)
    many_to_many :teams

    def before_create
      self.result_output ||= ""
      self.event_output ||= ""
    end

    def validate
      validates_presence [:state, :timestamp, :description]
    end

    def self.create_with_teams(attributes)
      teams = attributes.delete(:teams)
      task = create(attributes)
      task.teams = teams
      task
    end

    def teams=(teams)
      (teams || []).each do |t|
        self.add_team(t)
      end
    end
  end
end
