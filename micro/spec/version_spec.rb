require 'spec_helper'
require 'micro/version'

describe VCAP::Micro::Version do

  describe "file2version" do
    it "should return '1.2.3' for 'micro-1.2.3.tgz'" do
      VCAP::Micro::Version.file2version("micro-1.2.3.tgz").should == "1.2.3"
    end

    it "should return '1.2 rc1' for 'micro-1.2_rc1.tgz'" do
      VCAP::Micro::Version.file2version("micro-1.2_rc1.tgz").should == "1.2 rc1"
    end
  end

  describe "should_update?" do
    it "should return false for 0.9.0 and 1.0.0" do
      VCAP::Micro::Version.should_update?("0.9.0", "1.0.0").should be_true
    end

    it "should return false for 1.0.0 and 1.0.0" do
      VCAP::Micro::Version.should_update?("1.0.0", "1.0.0").should be_false
    end

    it "should return false for 1.2 and 1.2.3" do
      VCAP::Micro::Version.should_update?("1.2", "1.2.3").should be_false
    end

    it "should return true for 1.3 and 1.2.4" do
      VCAP::Micro::Version.should_update?("1.3", "1.2.4").should be_true
    end

    it "should return false for 1.4 and 1.5.3_rc1" do
      VCAP::Micro::Version.should_update?("1.4", "1.5.3_rc1").should be_false
    end

    it "should return true for 1.2.6 and 1.2.5" do
      VCAP::Micro::Version.should_update?("1.2.6", "1.2.5").should be_true
    end

    it "should return true for 2.7 and 1.7.4" do
      VCAP::Micro::Version.should_update?("2.7", "1.7.4").should be_true
    end
  end

end
