require 'spec_helper'

describe Bosh::Cli::ReleaseTarball do

  describe "verifying a release" do
    it "verifies and reports a valid release" do
      tarball = Bosh::Cli::ReleaseTarball.new(spec_asset("valid_release.tgz"))
      tarball.should be_valid
    end

    it "verifies repacked release if appropriate option is set" do
      tarball = Bosh::Cli::ReleaseTarball.new(spec_asset("valid_release.tgz"))
      repacked_tarball_path = tarball.repack(["mutator"], ["sweeper", "cacher"])

      repacked_tarball = Bosh::Cli::ReleaseTarball.new(repacked_tarball_path)
      repacked_tarball.valid?.should be_false
      repacked_tarball.reset_validation
      repacked_tarball.valid?(:allow_sparse => true).should be_true
    end
  end

  # TODO: add whining on potential errors

end
