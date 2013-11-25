# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::ReleaseTarball do

  describe "verifying a release" do
    it "verifies and reports a valid release" do
      tarball = Bosh::Cli::ReleaseTarball.new(spec_asset("valid_release.tgz"))
      tarball.should be_valid
    end

    it "verifies repacked release if appropriate option is set" do
      tarball = Bosh::Cli::ReleaseTarball.new(spec_asset("valid_release.tgz"))
      package_matches = ["86bd8b15562cde007f030a303fa64779af5fa4e7"]
      repacked_tarball_path = tarball.repack(package_matches)

      tarball.skipped.should == 1

      repacked_tarball = Bosh::Cli::ReleaseTarball.new(repacked_tarball_path)
      repacked_tarball.valid?.should be(false)
      repacked_tarball.reset_validation
      repacked_tarball.valid?(:allow_sparse => true).should be(true)
    end
  end
end
