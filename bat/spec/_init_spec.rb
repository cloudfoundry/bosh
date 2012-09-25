# Copyright (c) 2012 VMware, Inc.

require "spec_helper"

describe "initialization" do
  describe "environment" do
    %w[BAT_DIRECTOR BAT_STEMCELL BAT_DEPLOYMENT BAT_RELEASE_DIR].each do |var|
      it "should have #{var} set" do
        ENV[var].should_not be_nil
      end
    end

    describe "requirements" do
      it "should have a readable stemcell" do
        File.exist?(stemcell).should be_true
      end

      it "should have a sane stemcell version" do
        stemcell_version.should match /\d+\.\d+\.\d+/
      end

      it "should have readable releases" do
        bat_release_files.each do |file|
          File.exist?(file).should be_true
        end
      end

      it "should have sane release versions" do
        bat_release_files.each do |file|
          file.should match /\d+\.*\d*[-dev]*/
        end
      end

      it "should have a readable deployment" do
        File.exists?(deployment).should be_true
      end
    end
  end

  describe "director" do
    it "should be targetable" do
      bosh("target #{bosh_director}").should succeed_with /#{bosh_director}/
    end

    it "should not have a bat deployment" do
      deployments["bat"].should be_nil
    end

    it "should not have any bat releases" do
      releases["bat"].should be_nil
    end

    it "should not have any stemcells" do
      stemcells.should be_empty
    end
  end
end