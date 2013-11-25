# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

module Bosh::Director
  describe Api::UserManager do
    before do
      @user_manager = Api::UserManager.new
    end

    describe :authenticate do
      it 'should accept default username/password when no other accounts are present' do
        Models::User.all.should be_empty
        @user_manager.authenticate('admin', 'admin').should be(true)
      end

      it 'should not accept the default username/password when other accounts are present' do
        Models::User.make
        @user_manager.authenticate('admin', 'admin').should be(false)
      end

      it 'should authenticate normal users' do
        Models::User.make(username: 'foo', password: BCrypt::Password.create('bar'))
        Models::User.make(username: 'bad', password: BCrypt::Password.create('test'))

        @user_manager.authenticate('foo', 'bar').should be(true)
        @user_manager.authenticate('bad', 'Test').should be(false)
      end
    end

    describe :delete_user do
      it 'should delete existing users' do
        Models::User.make(username: 'foo')
        @user_manager.delete_user('foo')
        Models::User.find(username: 'foo').should be_nil
      end

      it 'should fail if the user does not exist' do
        lambda {
          @user_manager.delete_user('foo')
        }.should raise_error(UserNotFound)
      end
    end

    describe :create_user do
      it 'should create users' do
        user = Models::User.new(username: 'foo', password: 'bar')
        @user_manager.create_user(user)
        user = Models::User.find(username: 'foo')
        BCrypt::Password.new(user.password).should == 'bar'
      end

      it 'should not let you create two users with the same name' do
        user = Models::User.new(username: 'foo', password: 'bar')
        @user_manager.create_user(user)
        lambda {
          new_user = Models::User.new(username: 'foo', password: 'bar')
          @user_manager.create_user(new_user)
        }.should raise_error(UserNameTaken)
      end

      it 'should require a username' do
        lambda {
          user = Models::User.new(username: nil, password: 'bar')
          @user_manager.create_user(user)
        }.should raise_error(UserInvalid)
      end

      it 'should require a password' do
        lambda {
          user = Models::User.new(username: 'foo', password: nil)
          @user_manager.create_user(user)
        }.should raise_error(UserInvalid)
      end
    end

    describe :update_user do
      it 'should let you update the password' do
        Models::User.make(username: 'foo', password: 'old')
        user = Models::User.new(username: 'foo', password: 'bar')
        @user_manager.update_user(user)
        user = Models::User.find(username: 'foo')
        BCrypt::Password.new(user.password).should == 'bar'
      end
    end
  end
end
