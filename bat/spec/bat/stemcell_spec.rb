# Copyright (c) 2012 VMware, Inc.

require "spec_helper"

describe "stemcell" do
  it "should upload a stemcell" do
    bosh("upload stemcell #{stemcell}").should succeed_with /Stemcell uploaded/
    bosh("delete stemcell bosh-stemcell #{stemcell_version}")
  end

  it "should delete a stemcell" do
    bosh("upload stemcell #{stemcell}")
    bosh("delete stemcell bosh-stemcell #{stemcell_version}").should succeed_with /Deleted stemcell/
  end

  it "should not delete a stemcell in use" do
    bosh("upload release #{latest_bat_release}")
    bosh("upload stemcell #{stemcell}")

    with_deployment(deployment_spec) do |deployment|
      bosh("deployment #{deployment}")
      bosh("deploy")

      expect {
        bosh("delete stemcell bosh-stemcell #{stemcell_version}")
      }.to raise_error { |error|
        error.should be_a Bosh::Exec::Error
        error.output.should match /Error 50004/
      }
    end

    bosh("delete deployment bat")
    bosh("delete stemcell bosh-stemcell #{stemcell_version}")
    bosh("delete release bat")
  end
end
