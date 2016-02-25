require 'spec_helper'

module Bosh::Director
  describe PermissionAuthorizer do
    before do
      Bosh::Director::Models::DirectorAttribute.make(name: 'uuid', value: 'fake-director-uuid')
    end

    describe '#is_granted?' do
      describe 'director subject' do
        let(:acl_subject) { :director }

        describe 'checking admin rights' do
          let(:acl_right) { :admin }

          it 'allows global admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.admin'])).to eq(true)
          end

          it 'allows director-specific admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.fake-director-uuid.admin'])).to eq(true)
          end

          it 'denies others' do
            expect(subject.is_granted?(acl_subject, acl_right, [
                  'bosh.unexpected-uuid.admin',   # other director-specific admin scope
                  'bosh.teams.security.admin',    # team specific admins
                  'bosh.read',                    # read != admin
                  'bosh.fake-director-uuid.read', # other director-specific read != admin
                ])).to eq(false)
          end
        end

        describe 'checking read rights' do
          let(:acl_right) { :read }

          it 'allows global admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.admin'])).to eq(true)
          end

          it 'allows director-specific admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.fake-director-uuid.admin'])).to eq(true)
          end

          it 'allows global read scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.read'])).to eq(true)
          end

          it 'allows director-specific read scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.fake-director-uuid.read'])).to eq(true)
          end

          it 'denies others' do
            expect(subject.is_granted?(acl_subject, acl_right, [
                  'bosh.unexpected-uuid.admin', # other director-specific admin scope
                  'bosh.unexpected-uuid.read',  # other director-specific read != admin
                  'bosh.teams.security.admin',  # team specific admins
                ])).to eq(false)
          end
        end

        describe 'checking for create_deployment rights' do
          let(:acl_right) { :create_deployment }

          it 'allows global admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.admin'])).to eq(true)
          end

          it 'allows director-specific admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.fake-director-uuid.admin'])).to eq(true)
          end

          it 'allows team admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.teams.security.admin'])).to eq(true)
          end

          it 'denies others' do
            expect(subject.is_granted?(acl_subject, acl_right, [
                  'bosh.read', # denies global read scope
                  'bosh.fake-director-uuid.read', # denies director-specific read scope
                  'bosh.unexpected-uuid.admin', # other director-specific admin scope
                  'bosh.unexpected-uuid.read',  # other director-specific read != admin
                  'bosh.teams.security.read',  # team specific reads
                ])).to eq(false)
          end
        end

        describe 'checking for list_deployments rights' do
          let(:acl_right) { :list_deployments }

          it 'allows global admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.admin'])).to eq(true)
          end

          it 'allows global read scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.read'])).to eq(true)
          end

          it 'allows director-specific admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.fake-director-uuid.admin'])).to eq(true)
          end

          it 'allows director-specific read scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.fake-director-uuid.read'])).to eq(true)
          end

          it 'allows team admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.teams.security.admin'])).to eq(true)
          end

          it 'allows team read scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.teams.security.read'])).to eq(true)
          end

          it 'denies others' do
            expect(subject.is_granted?(acl_subject, acl_right, [
                  'bosh.unexpected-uuid.admin', # other director-specific admin scope
                  'bosh.unexpected-uuid.read',  # other director-specific read != admin
                  'bosh.teams.security.unexpected',  # abnormal team-specific scope
                ])).to eq(false)
          end
        end

        describe 'checking for invalid rights' do
          let(:acl_right) { :what_I_fancy }

          it 'raises an exception' do
            expect{
              subject.is_granted?(acl_subject, acl_right, ['bosh.admin'])
            }.to raise_error ArgumentError, "Unexpected right for director: #{acl_right}"
          end
        end
      end

      describe 'deployment' do
        let(:acl_subject) { Models::Deployment.make(name: 'favorite', teams: 'security') }

        describe 'checking admin rights' do
          let(:acl_right) { :admin }

          it 'allows global admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.admin'])).to eq(true)
          end

          it 'allows director-specific admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.fake-director-uuid.admin'])).to eq(true)
          end

          it 'allows team admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.teams.security.admin'])).to eq(true)
          end

          it 'denies others' do
            expect(subject.is_granted?(acl_subject, acl_right, [
                  'bosh.unexpected-uuid.admin',   # other director-specific admin scope
                  'bosh.teams.fraud.admin',       # unrelated team specific admins
                  'bosh.teams.security.read',     # team specific read
                  'bosh.read',                    # read != admin
                  'bosh.fake-director-uuid.read', # other director-specific read != admin
                ])).to eq(false)
          end
        end

        describe 'checking read rights' do
          let(:acl_right) { :read }

          it 'allows global admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.admin'])).to eq(true)
          end

          it 'allows director-specific admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.fake-director-uuid.admin'])).to eq(true)
          end

          it 'allows global read scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.read'])).to eq(true)
          end

          it 'allows director-specific read scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.fake-director-uuid.read'])).to eq(true)
          end

          it 'allows team admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.teams.security.admin'])).to eq(true)
          end

          it 'allows team read scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.teams.security.read'])).to eq(true)
          end

          it 'denies others' do
            expect(subject.is_granted?(acl_subject, acl_right, [
                  'bosh.unexpected-uuid.admin', # other director-specific admin scope
                  'bosh.unexpected-uuid.read',  # other director-specific read != admin
                  'bosh.teams.fraud.admin',     # unrelated team specific scope
                ])).to eq(false)
          end
        end

        describe 'checking for invalid rights' do
          let(:acl_right) { :what_I_fancy }

          it 'raises an exception' do
            expect{
              subject.is_granted?(acl_subject, acl_right, ['bosh.admin'])
            }.to raise_error ArgumentError, "Unexpected right for deployment: #{acl_right}"
          end
        end
      end

      describe 'unexpected subject' do
        let(:acl_subject) { :subject_I_fancy }
        let(:acl_right) { :read }

        it 'raises an exception' do
          expect{
            subject.is_granted?(acl_subject, acl_right, ['bosh.admin'])
          }.to raise_error ArgumentError, "Unexpected subject: #{acl_subject}"
        end
      end
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

    describe '#transform_team_scope_to_teams' do
      it 'returns an array of team names from scope format' do
        token_scopes = ['bosh.teams.prod.admin']
        expect(subject.transform_admin_team_scope_to_teams(token_scopes)).to eq(['prod'])
      end

      it 'returns an empty array if no valid token_scopes are found' do
        token_scopes = ['bosh.admin']
        expect(subject.transform_admin_team_scope_to_teams(token_scopes)).to eq([])
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
