module Bosh::Director::Models
  class Team < Sequel::Model(Bosh::Director::Config.db)
    many_to_many :deployment

    def validate
      validates_presence [:name]
    end

    def self.transform_admin_team_scope_to_teams(token_scopes)
      return [] if token_scopes.nil?
      team_scopes = token_scopes.map do |scope|
        match = scope.match(/\Abosh\.teams\.([^\.]*)\.admin\z/)
        match[1] unless match.nil?
      end
      team_names = team_scopes.compact
      team_names.map do |name|
        found = find({name: name})
        if !found
          found = create({name: name})
        end
        found
      end
    end
  end
end
