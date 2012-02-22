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
      remote_release = {
        "packages" => [ { "name" => "mutator", "version" => "2.99.7" } ],
        "jobs" => [ { "name" => "cacher", "version" => "1" }, { "name" => "sweeper", "version" => "1" } ]
      }
      repacked_tarball_path = tarball.repack(remote_release)

      tarball.skipped.should == 2

      repacked_tarball = Bosh::Cli::ReleaseTarball.new(repacked_tarball_path)
      repacked_tarball.valid?.should be_false
      repacked_tarball.reset_validation
      repacked_tarball.valid?(:allow_sparse => true).should be_true
    end
  end

  # TODO: add whining on potential errors

end
