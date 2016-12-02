require 'spec_helper'

module Bosh::Director::Models
  describe Team do
    describe '#transform_team_scope_to_teams' do
      it 'returns an array of teams from scope format' do
        token_scopes = ['bosh.teams.prod.admin']
        team = Team.transform_admin_team_scope_to_teams(token_scopes)
        expect(team[0].name).to eq('prod')
      end

      it 'returns an empty array if no valid token_scopes are found' do
        token_scopes = ['bosh.admin']
        expect(Team.transform_admin_team_scope_to_teams(token_scopes)).to eq([])
      end

      context 'when team exists in database' do
        it 'returns the team' do
          team = Team.create(name: 'some_scope')
          token_scopes = ['bosh.teams.some_scope.admin']
          expect(Team.transform_admin_team_scope_to_teams(token_scopes)).to include(team)
        end
      end

      context 'when team does not exist in database' do
        it 'returns a team' do
          token_scopes = ['bosh.teams.some_scope.admin']
          expect(Team.transform_admin_team_scope_to_teams(token_scopes)).to include(Team.find(name: 'some_scope'))
        end
      end
    end
  end
end
