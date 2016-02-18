require 'spec_helper'

module Bosh::Director
  describe PermissionAuthorizer do
    before do
      Bosh::Director::Models::DirectorAttribute.make(name: 'uuid', value: 'fake-director-uuid')
    end

    describe '#has_admin_scope?' do
      it 'should return true for bosh.admin' do
        token_scope = ['bosh.admin']
        expect(subject.has_admin_scope?(token_scope)).to eq(true)
      end

      it 'should return false for an empty scope parameter' do
        expect(subject.has_admin_scope?([])).to eq(false)
      end

      it 'should return false for a different director' do
        token_scope = ['bosh.director-that-does-not-exist.admin']
        expect(subject.has_admin_scope?(token_scope)).to eq(false)
      end
    end

    describe '#has_team_admin_scope?' do
      it 'should return true for token_scope with team.admin permissions' do
        token_scope = ['bosh.teams.made-up-team.admin']
        expect(subject.has_team_admin_scope?(token_scope)).to eq(true)
      end

      it 'should return false for token_scope without team.admin permissions' do
        token_scope = ['bosh.admin', 'bosh.read']
        expect(subject.has_team_admin_scope?(token_scope)).to eq(false)
      end
    end
  end
end
