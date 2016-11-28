require 'spec_helper'

module Bosh::Director
  describe Api::ConfigUserManager do
    subject(:user_manager) { Api::ConfigUserManager.new(users) }
    let(:users) do
      [
        {'name' => 'fake-user', 'password' => 'fake-pass'},
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
  end
end
