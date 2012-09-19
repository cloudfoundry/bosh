# Copyright (c) 2012 VMware, Inc.

require "spec_helper"

describe "release" do
  describe "upload" do
    before(:each) do
      bosh("upload release #{previous_bat_release}")
    end

    after(:each) do
      bosh("delete release bat")
    end

    it "should succeed when the release is valid" do
      bosh("upload release #{latest_bat_release}").should
        succeed_with /Release uploaded/
    end

    it "should fail when the release already is uploaded" do
      expect { bosh("upload release #{previous_bat_release}") }.to raise_error { |error|
        error.should be_a Bosh::Exec::Error
        error.output.should match /This release version has already been uploaded/
      }
    end
  end

  describe "delete" do

    context "in use" do
      before(:all) do
        bosh("upload release #{latest_bat_release}")
        bosh("upload stemcell #{stemcell}")
        @deployment = with_deployment(deployment_spec)
        bosh("deployment #{@deployment}")
        bosh("deploy")
      end

      after(:all) do
        bosh("delete deployment bat")
        FileUtils.rm(@deployment)
        bosh("delete stemcell bosh-stemcell #{stemcell_version}")
        bosh("delete release bat")
      end

      it "should not be possible to delete" do
        expect {
          bosh("delete release bat")
        }.to raise_error { |error|
          error.should be_a Bosh::Exec::Error
          error.output.should match /Error 30007/
        }
      end

      it "should be possible to delete a different version" do
        bosh("upload release #{previous_bat_release}")
        bosh("delete release bat #{previous_bat_version}").should
          succeed_with /Deleted release/
      end
    end

    context "not in use" do
      before(:each) do
        bosh("upload release #{latest_bat_release}")
        bosh("upload release #{previous_bat_release}")
      end

      it "should be possible to delete a single release" do
        bosh("delete release bat #{previous_bat_version}").should
          succeed_with /Deleted release/
        releases["bat"].should_not include(previous_bat_version)
        bosh("delete release bat")
      end

      it "should be possible to delete all releases" do
        bosh("delete release bat").should succeed_with /Deleted release/
        releases["bat"].should be_nil
      end
    end
  end
end
