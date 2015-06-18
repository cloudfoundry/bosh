# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

module Bosh::Director
  describe Api::DatabaseUserManager do
    before do
      @user_manager = Api::DatabaseUserManager.new
    end

    describe :authenticate do
      it 'should accept default username/password when no other accounts are present' do
        expect(Models::User.all).to be_empty
        expect(@user_manager.authenticate('admin', 'admin')).to be(true)
      end

      it 'should not accept the default username/password when other accounts are present' do
        Models::User.make
        expect(@user_manager.authenticate('admin', 'admin')).to be(false)
      end

      it 'should authenticate normal users' do
        Models::User.make(username: 'foo', password: BCrypt::Password.create('bar'))
        Models::User.make(username: 'bad', password: BCrypt::Password.create('test'))

        expect(@user_manager.authenticate('foo', 'bar')).to be(true)
        expect(@user_manager.authenticate('bad', 'Test')).to be(false)
      end
    end

    describe :delete_user do
      it 'should delete existing users' do
        Models::User.make(username: 'foo')
        @user_manager.delete_user('foo')
        expect(Models::User.find(username: 'foo')).to be_nil
      end

      it 'should fail if the user does not exist' do
        expect {
          @user_manager.delete_user('foo')
        }.to raise_error(UserNotFound)
      end

      context 'when the user is associated to a task' do
        it 'should delete the user' do
          darth = Models::User.make(username: 'darth')
          task = Models::Task.make(username: darth.username)

          @user_manager.delete_user('darth')

          expect(Models::User.find(username: 'darth')).to be_nil
          expect(Models::Task.find(id: task.id).username).to eq('darth')
        end
      end
    end

    describe :create_user do
      it 'should create users' do
        user = Models::User.new(username: 'foo', password: 'bar')
        @user_manager.create_user(user)
        user = Models::User.find(username: 'foo')
        expect(BCrypt::Password.new(user.password)).to eq('bar')
      end

      it 'should not let you create two users with the same name' do
        user = Models::User.new(username: 'foo', password: 'bar')
        @user_manager.create_user(user)
        expect {
          new_user = Models::User.new(username: 'foo', password: 'bar')
          @user_manager.create_user(new_user)
        }.to raise_error(UserNameTaken)
      end

      it 'should require a username' do
        expect {
          user = Models::User.new(username: nil, password: 'bar')
          @user_manager.create_user(user)
        }.to raise_error(UserInvalid)
      end

      it 'should require a password' do
        expect {
          user = Models::User.new(username: 'foo', password: nil)
          @user_manager.create_user(user)
        }.to raise_error(UserInvalid)
      end
    end

    describe :update_user do
      it 'should let you update the password' do
        Models::User.make(username: 'foo', password: 'old')
        user = Models::User.new(username: 'foo', password: 'bar')
        @user_manager.update_user(user)
        user = Models::User.find(username: 'foo')
        expect(BCrypt::Password.new(user.password)).to eq('bar')
      end
    end
  end
end
