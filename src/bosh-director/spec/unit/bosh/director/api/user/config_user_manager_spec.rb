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
        {'name' => 'nil-pass'},
      ]
    end

    describe :authenticate do
      it 'should authenticate registered users' do
        expect(user_manager.authenticate('fake-user', 'fake-pass')).to be(true)
        expect(user_manager.authenticate('bad', 'Test')).to be(false)
      end

      it 'rejects incorrect passwords of different lengths' do
        expect(user_manager.authenticate('fake-user', 'fake-pas')).to be(false)
        expect(user_manager.authenticate('fake-user', 'fake-pass-extra')).to be(false)
      end

      it 'compares fixed length digests for registered users' do
        expect(OpenSSL).to receive(:fixed_length_secure_compare).with(
          Digest::SHA256.digest('fake-pass'), Digest::SHA256.digest('fake-pass'),
        ).and_call_original
        expect(user_manager.authenticate('fake-user', 'fake-pass')).to be(true)
      end

      it 'still performs a comparison for an unknown user' do
        expect(OpenSSL).to receive(:fixed_length_secure_compare).with(
          Digest::SHA256.digest(''), Digest::SHA256.digest('fake-pass'),
        ).and_call_original
        expect(user_manager.authenticate('unknown-user', 'fake-pass')).to be(false)
      end

      it 'rejects users with no configured password' do
        expect(user_manager.authenticate('nil-pass', 'fake-pass')).to be(false)
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
        expect{user_manager.user_scopes('unknown-user')}.to raise_error(RuntimeError, /User unknown-user not found in ConfigUserManager/)
      end
    end
  end
end
