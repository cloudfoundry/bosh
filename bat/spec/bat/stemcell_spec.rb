# Copyright (c) 2012 VMware, Inc.

require "spec_helper"

describe "stemcell" do

  before(:each) do
    load_deployment_spec
  end

  # for the sake of speed this test does two things:
  # if the stemcell is already uploaded, it deletes it and then uploads it
  # if it isn't uploaded, it uploads it and then deletes it
  # i.e. the state is the same as before the test is run
  it "should upload and delete a stemcell" do
    if stemcells.include?(stemcell)
      deployments.should_not include(release.name)
      bosh("delete stemcell #{stemcell.name} #{stemcell.version}").should succeed_with /Deleted stemcell/
      bosh("upload stemcell #{stemcell.to_path}").should succeed_with /Stemcell uploaded/
    else
      bosh("upload stemcell #{stemcell.to_path}").should succeed_with /Stemcell uploaded/
      bosh("delete stemcell #{stemcell.name} #{stemcell.version}").should succeed_with /Deleted stemcell/
    end
    cleanup stemcell
  end

  it "should not delete a stemcell in use" do
    requirement stemcell
    requirement release

    with_deployment do
      expect {
        bosh("delete stemcell #{stemcell.name} #{stemcell.version}")
      }.to raise_error { |error|
        error.should be_a Bosh::Exec::Error
        error.output.should match /Error 50004/
      }
    end

    cleanup release
    cleanup stemcell
  end
end
