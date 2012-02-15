# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::Stemcell do

  describe "verifying a stemcell" do
    it "verifies and reports a valid stemcell" do
      sc = Bosh::Cli::Stemcell.new(spec_asset("valid_stemcell.tgz"), Bosh::Cli::Cache.new(Dir.mktmpdir))
      sc.should be_valid
    end    
  end

  # TODO: add whining on potential errors
  
end
