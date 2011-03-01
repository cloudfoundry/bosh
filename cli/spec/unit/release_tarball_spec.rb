require 'spec_helper'

describe Bosh::Cli::ReleaseTarball do

  describe "verifying a release" do
    it "verifies and reports a valid release" do
      tarball = Bosh::Cli::ReleaseTarball.new(spec_asset("valid_release.tgz"))
      tarball.should be_valid
    end
  end

  # TODO: add whining on potential errors

end
