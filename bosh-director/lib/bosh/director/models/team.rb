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
        create_or_find(name)
      end
    end

    private

    # this fixes potential race condition when
    # multiple creates happen at the same time
    def self.create_or_find(name)
      begin
        found = create(name: name)
      rescue Exception => e
        found = find(name: name)
        raise e if !found
      end
      found
    end
  end
end
