require 'spec_helper'

module Bosh::Director
  describe Api::ConfigUserManager do
    subject(:user_manager) { Api::ConfigUserManager.new(users) }
    let(:users) do
      [
        {'name' => 'fake-user', 'password' => 'fake-pass'},
        {'name' => 'fake-ro-user', 'password' => 'fake-pass', 'scopes' => [ 'bosh.read' ]},
        {'name' => '', 'password' => 'no-user'},
        {'name' => 'no-pass', 'password' => ''},
      ]
    end

    describe :authenticate do
      it 'should authenticate registered users' do
        expect(user_manager.authenticate('fake-user', 'fake-pass')).to be(true)
        expect(user_manager.authenticate('bad', 'Test')).to be(false)
      end

      it 'should not authenticate users without username' do
        expect(user_manager.authenticate('', 'no-user')).to be(false)
      end

      it 'should not authenticate users without password' do
        expect(user_manager.authenticate('no-pass', '')).to be(false)
      end
    end

    describe :user_scopes do
      it 'should return the scopes provided in the config' do
        expect(user_manager.user_scopes('fake-ro-user')).to contain_exactly('bosh.read')
      end
      it 'should return bosh.admin if no scopes defined in config' do
        expect(user_manager.user_scopes('fake-user')).to contain_exactly('bosh.admin')
      end
      it 'should raise error if user does not exist' do
        expect{user_manager.user_scopes('unkown-user')}.to raise_error(RuntimeError, /User unkown-user not found in ConfigUserManager/)
      end
    end
  end
end
