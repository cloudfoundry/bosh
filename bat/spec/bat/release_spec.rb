# Copyright (c) 2012 VMware, Inc.

require "spec_helper"

describe "release" do

  before(:all) do
    requirement stemcell
    requirement release
  end

  after(:all) do
    cleanup release
    cleanup stemcell
  end

  before(:each) do
    load_deployment_spec
    @previous = release.previous
    if releases.include?(@previous)
      bosh("delete release #{@previous.name} #{@previous.version}")
    end
  end

  describe "upload" do
    it "should succeed when the release is valid" do
      bosh("upload release #{@previous.to_path}").should
        succeed_with /Release uploaded/
    end

    it "should fail when the release already is uploaded" do
      expect {
        bosh("upload release #{release.to_path}")
      }.to raise_error { |error|
        error.should be_a Bosh::Exec::Error
        error.output.should match /This release version has already been uploaded/
      }
    end
  end

  describe "delete" do

    before(:each) do
      bosh("upload release #{@previous.to_path}")
    end

    context "in use" do

      it "should not be possible to delete" do
        expect {
          with_deployment do
            bosh("delete release #{@previous.name}")
          end
        }.to raise_error { |error|
          error.should be_a Bosh::Exec::Error
          error.output.should match /Error 30007/
        }
        bosh("delete release #{@previous.name} #{@previous.version}")
      end

      it "should be possible to delete a different version" do
        with_deployment do
          bosh("delete release #{@previous.name} #{@previous.version}").should
            succeed_with /Deleted release/
        end
      end
    end

    context "not in use" do
      it "should be possible to delete a single release" do
        bosh("delete release #{@previous.name} #{@previous.version}").should
          succeed_with /Deleted release/
        releases.should_not include(@previous)
      end

      it "should be possible to delete all releases" do
        bosh("delete release #{release.name}").should succeed_with /Deleted `#{release.name}'/
        releases.should_not include(release)
        # TODO this fails when running in fast mode, as it tries to delete the release too
      end
    end
  end
end
