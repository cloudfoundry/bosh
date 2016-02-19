require 'spec_helper'

module Bosh::Director
  describe PermissionAuthorizer do
    before do
      Bosh::Director::Models::DirectorAttribute.make(name: 'uuid', value: 'fake-director-uuid')
    end

    describe '#has_admin_or_director_scope?' do
      it 'should return true for bosh.admin' do
        token_scope = ['bosh.admin']
        expect(subject.has_admin_or_director_scope?(token_scope)).to eq(true)
      end

      it 'should return false for an empty scope parameter' do
        expect(subject.has_admin_or_director_scope?([])).to eq(false)
      end

      it 'should return false for a different director' do
        token_scope = ['bosh.director-that-does-not-exist.admin']
        expect(subject.has_admin_or_director_scope?(token_scope)).to eq(false)
      end
    end

    describe '#has_admin_or_director_read_scope?' do
      it 'should return true for bosh.admin' do
        token_scope = ['bosh.admin']
        expect(subject.has_admin_or_director_read_scope?(token_scope)).to eq(true)
      end

      it 'should return true for bosh.read' do
        token_scope = ['bosh.read']
        expect(subject.has_admin_or_director_read_scope?(token_scope)).to eq(true)
      end

      it 'should return false for an empty scope parameter' do
        expect(subject.has_admin_or_director_read_scope?([])).to eq(false)
      end

      it 'should return false for a different director' do
        token_scope = ['bosh.director-that-does-not-exist.read']
        expect(subject.has_admin_or_director_read_scope?(token_scope)).to eq(false)
      end

      it 'should return true for a director readonly permissions' do
        token_scope = ['bosh.fake-director-uuid.read']
        expect(subject.has_admin_or_director_read_scope?(token_scope)).to eq(true)
      end
    end

    describe '#contains_requested_scope?' do
      it 'should return true for bosh.admin' do
        valid_scope = ['bosh.admin']
        token_scope = ['bosh.admin']

        expect(subject.contains_requested_scope?(valid_scope, token_scope)).to eq(true)
      end

      it 'should return false for non-overlapping scopes' do
        valid_scope = ['bosh.admin']
        token_scope = ['bosh.teams.dev.admin']

        expect(subject.contains_requested_scope?(valid_scope, token_scope)).to eq(false)
      end
    end

    describe '#is_authorized_to_read?' do
      context 'token scope has admin scope' do
        it 'returns true' do
          valid_scope = ['bosh.teams.dev.admin']
          token_scope = ['bosh.admin']
          expect(subject.is_authorized_to_read?(valid_scope, token_scope)).to eq(true)
        end
      end

      context 'token scope has team scope' do
        it 'returns true' do
          valid_scope = ['bosh.teams.dev.admin', 'bosh.teams.prod.admin']
          token_scope = ['bosh.teams.dev.admin']
          expect(subject.is_authorized_to_read?(valid_scope, token_scope)).to eq(true)
        end
      end

      context 'token scope has director readonly scope' do
        it 'returns true' do
          valid_scope = []
          token_scope = ['bosh.fake-director-uuid.read']
          expect(subject.is_authorized_to_read?(valid_scope, token_scope)).to eq(true)
        end
      end

      context 'token scope has no team scope' do
        it 'returns false' do
          valid_scope = ['bosh.teams.dev.admin']
          token_scope = ['bosh.teams.prod.admin']
          expect(subject.is_authorized_to_read?(valid_scope, token_scope)).to eq(false)
        end
      end
    end

    describe '#raise_error_if_no_write_permissions' do
      context 'provided scopes have bosh.admin' do
        it 'does not raise an exception' do
          token_scope = ['bosh.admin']
          expect {
            subject.raise_error_if_no_write_permissions(token_scope, [])
          }.not_to raise_error
        end
      end

      context 'provided scopes have bosh.admin and unknown director' do
        it 'does not raise an exception' do
          token_scope = ['bosh.admin', 'bosh.unknown-director.admin']
          expect {
            subject.raise_error_if_no_write_permissions(token_scope, [])
          }.not_to raise_error
        end
      end

      context 'provided scopes have bosh.fake-director-uuid.admin' do
        it 'does not raise an exception' do
          token_scope = ['bosh.fake-director-uuid.admin']
          expect {
            subject.raise_error_if_no_write_permissions(token_scope, [])
          }.not_to raise_error
        end
      end

      context 'provided scopes and deployment teams parameter have bosh.teams.fake-team.admin' do
        it 'does not raise an exception' do
          token_scope = ['bosh.teams.fake-team.admin']
          expect {
            subject.raise_error_if_no_write_permissions(token_scope, ['bosh.teams.fake-team.admin'])
          }.not_to raise_error
        end
      end

      context 'provided no scopes' do
        it 'does raise an exception' do
          expect {
            subject.raise_error_if_no_write_permissions([], [])
          }.to raise_error(UnauthorizedToAccessDeployment)
        end
      end

      context 'director uuid is different from provided scopes' do
        it 'does raise an exception' do
          expect {
            token_scope = ['bosh.unknown-director.admin']
            subject.raise_error_if_no_write_permissions(token_scope, [])
          }.to raise_error(UnauthorizedToAccessDeployment)
        end
      end

      context 'provided scopes are different from team scopes' do
        it 'does raise an exception' do
          expect {
            token_scope = ['bosh.teams.team-a.admin']
            subject.raise_error_if_no_write_permissions(token_scope, ['bosh.teams.team-b.admin'])
          }.to raise_error(UnauthorizedToAccessDeployment)
        end
      end

      context 'provided scopes has readonly permissions' do
        it 'does raise an exception' do
          expect {
            token_scope = ['bosh.read', 'bosh.fake-director-uuid.read']
            subject.raise_error_if_no_write_permissions(token_scope, [])
          }.to raise_error(UnauthorizedToAccessDeployment)
        end
      end
    end

    describe '#transform_team_scope_to_teams' do
      it 'returns an array of team names from scope format' do
        token_scopes = ['bosh.teams.prod.admin']
        expect(subject.transform_team_scope_to_teams(token_scopes)).to eq(['prod'])
      end

      it 'returns an empty array if no valid token_scopes are found' do
        token_scopes = ['bosh.admin']
        expect(subject.transform_team_scope_to_teams(token_scopes)).to eq([])
      end
    end

    describe '#transform_teams_to_team_scopes' do
      it 'returns an array of team names in scope format' do
        teams = ['prod']
        expect(subject.transform_teams_to_team_scopes(teams)).to eq(['bosh.teams.prod.admin'])
      end

      it 'returns an empty array if no valid team names are used' do
        teams = []
        expect(subject.transform_teams_to_team_scopes(teams)).to eq([])
      end
    end
  end
end
