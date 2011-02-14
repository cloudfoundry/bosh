require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Director::UserManager do

  before(:each) do
    @user_manager = Bosh::Director::UserManager.new
  end

  describe "authenticate" do

    it "should accept default username/password when no other accounts are present" do
      Bosh::Director::Models::User.all.should be_empty
      @user_manager.authenticate("admin", "admin").should be_true
    end

    it "should not accept the default username/password when other accounts are present" do
      Bosh::Director::Models::User.make
      @user_manager.authenticate("admin", "admin").should be_false
    end

    it "should authenticate normal users" do
      Bosh::Director::Models::User.make(:username => "foo", :password => BCrypt::Password.create("bar"))
      Bosh::Director::Models::User.make(:username => "bad", :password => BCrypt::Password.create("test"))

      @user_manager.authenticate("foo", "bar").should be_true
      @user_manager.authenticate("bad", "Test").should be_false
    end

  end

  describe "delete_user" do

    it "should delete existing users" do
      Bosh::Director::Models::User.make(:username => "foo")
      @user_manager.delete_user("foo")
      Bosh::Director::Models::User.find(:username => "foo").should be_nil
    end

    it "should fail if the user does not exist" do
      lambda { @user_manager.delete_user("foo") }.should raise_error Bosh::Director::UserNotFound
    end

  end

  describe "create_user" do

    it "should create users" do
      @user_manager.create_user(Bosh::Director::Models::User.make_unsaved(:username => "foo", :password => "bar"))
      user = Bosh::Director::Models::User.find(:username => "foo")
      BCrypt::Password.new(user.password).should == "bar"
    end

    it "should not let you create two users with the same name" do
      @user_manager.create_user(Bosh::Director::Models::User.make_unsaved(:username => "foo", :password => "bar"))
      lambda {
        @user_manager.create_user(Bosh::Director::Models::User.make_unsaved(:username => "foo", :password => "bar"))
      }.should raise_error Bosh::Director::UserNameTaken
    end

    it "should require a username" do
      lambda {
        @user_manager.create_user(Bosh::Director::Models::User.make_unsaved(:username => nil, :password => "bar"))
      }.should raise_error Bosh::Director::UserInvalid
    end

    it "should require a password" do
      lambda {
        @user_manager.create_user(Bosh::Director::Models::User.make_unsaved(:username => "foo", :password => nil))
      }.should raise_error Bosh::Director::UserInvalid
    end

  end

  describe "update_user" do

    it "should let you update the password" do
      Bosh::Director::Models::User.make(:username => "foo", :password => "old")
      @user_manager.update_user(Bosh::Director::Models::User.make_unsaved(:username => "foo", :password => "bar"))
      user = Bosh::Director::Models::User.find(:username => "foo")
      BCrypt::Password.new(user.password).should == "bar"
    end

  end

end