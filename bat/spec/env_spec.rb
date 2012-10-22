# Copyright (c) 2012 VMware, Inc.

require "spec_helper"

describe "initialization" do
  describe "environment" do
    %w[
      BAT_DIRECTOR
      BAT_STEMCELL
      BAT_DEPLOYMENT_SPEC
      BAT_VCAP_PASSWORD
      BAT_RELEASE_DIR
    ].each do |var|
      it "should have #{var} set" do
        ENV[var].should_not be_nil
      end
    end

    describe "requirements" do
      it "should have a readable stemcell" do
        File.exist?(stemcell.to_path).should be_true
      end

      it "should have readable releases" do
        File.exist?(release.to_path).should be_true
      end

      it "should have a readable deployment" do
        load_deployment_spec
        with_deployment do |deployment|
          File.exists?(deployment.to_path).should be_true
        end
      end
    end
  end

  describe "director" do
    it "should be targetable" do
      bosh("target #{bosh_director}").should succeed_with /Target \w*\s*set/
    end

    it "should fetch deployments" do
      deployments.should_not be_nil
    end

    it "should fetch releases" do
      releases.should_not be_nil
    end

    it "should fetch stemcells" do
      stemcells.each { |s| s.should_not be_nil }
    end
  end
end
