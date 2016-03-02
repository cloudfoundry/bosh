require 'spec_helper'

module Bosh::Director::Models
  describe Deployment do
    describe '#transform_team_scope_to_teams' do
      it 'returns an array of team names from scope format' do
        token_scopes = ['bosh.teams.prod.admin']
        expect(Deployment.transform_admin_team_scope_to_teams(token_scopes)).to eq(['prod'])
      end

      it 'returns an empty array if no valid token_scopes are found' do
        token_scopes = ['bosh.admin']
        expect(Deployment.transform_admin_team_scope_to_teams(token_scopes)).to eq([])
      end
    end
  end
end
