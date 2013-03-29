# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::YamlHelper do
  subject { Bosh::Cli::YamlHelper }

  describe "#check_duplicate_keys" do
    context "when YAML contains aliases and anchors" do
      it "does not raise an error" do
        expect {
          subject.check_duplicate_keys("ccdb: &ccdb\n  db_scheme: mysql\nccdb_ng: *ccdb")
        }.not_to raise_error
      end
    end
  end
end
