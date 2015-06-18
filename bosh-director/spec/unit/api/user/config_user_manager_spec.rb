require 'spec_helper'

module Bosh::Director
  describe Api::ConfigUserManager do
    subject(:user_manager) { Api::ConfigUserManager.new(users) }
    let(:users) { [{'name' => 'fake-user', 'password' => 'fake-pass' }]}

    describe :authenticate do
      it 'should authenticate registered users' do
        expect(user_manager.authenticate('fake-user', 'fake-pass')).to be(true)
        expect(user_manager.authenticate('bad', 'Test')).to be(false)
      end
    end
  end
end
