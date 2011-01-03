require 'spec_helper'

describe Bosh::Cli::Release do

  describe "verifying a release" do
    it "verifies and reports a valid release" do
      release = Bosh::Cli::Release.new(spec_asset("valid_release.tgz"))
      release.should be_valid
    end
  end

  # TODO: add whining on potential errors  
  
end
