# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::Api::UserManager do
  before(:each) do
    @user_manager = BDA::UserManager.new
  end

  describe :authenticate do
    it "should accept default username/password when no other accounts are present" do
      BD::Models::User.all.should be_empty
      @user_manager.authenticate("admin", "admin").should be_true
    end

    it "should not accept the default username/password when other accounts are present" do
      BD::Models::User.make
      @user_manager.authenticate("admin", "admin").should be_false
    end

    it "should authenticate normal users" do
      BD::Models::User.make(:username => "foo",
                            :password => BCrypt::Password.create("bar"))
      BD::Models::User.make(:username => "bad",
                            :password => BCrypt::Password.create("test"))

      @user_manager.authenticate("foo", "bar").should be_true
      @user_manager.authenticate("bad", "Test").should be_false
    end
  end

  describe :delete_user do
    it "should delete existing users" do
      BD::Models::User.make(:username => "foo")
      @user_manager.delete_user("foo")
      BD::Models::User.find(:username => "foo").should be_nil
    end

    it "should fail if the user does not exist" do
      lambda {
        @user_manager.delete_user("foo")
      }.should raise_error(BD::UserNotFound)
    end
  end

  describe :create_user do
    it "should create users" do
      user = BD::Models::User.new(:username => "foo",
                                  :password => "bar")
      @user_manager.create_user(user)
      user = BD::Models::User.find(:username => "foo")
      BCrypt::Password.new(user.password).should == "bar"
    end

    it "should not let you create two users with the same name" do
      user = BD::Models::User.new(:username => "foo",
                                  :password => "bar")
      @user_manager.create_user(user)
      lambda {
        new_user = BD::Models::User.new(:username => "foo",
                                        :password => "bar")
        @user_manager.create_user(new_user)
      }.should raise_error(BD::UserNameTaken)
    end

    it "should require a username" do
      lambda {
        user = BD::Models::User.new(:username => nil,
                                    :password => "bar")
        @user_manager.create_user(user)
      }.should raise_error(BD::UserInvalid)
    end

    it "should require a password" do
      lambda {
        user = BD::Models::User.new(:username => "foo",
                                    :password => nil)
        @user_manager.create_user(user)
      }.should raise_error(BD::UserInvalid)
    end
  end

  describe :update_user do
    it "should let you update the password" do
      BD::Models::User.make(:username => "foo", :password => "old")
      user = BD::Models::User.new(:username => "foo",
                                  :password => "bar")
      @user_manager.update_user(user)
      user = BD::Models::User.find(:username => "foo")
      BCrypt::Password.new(user.password).should == "bar"
    end
  end
end
