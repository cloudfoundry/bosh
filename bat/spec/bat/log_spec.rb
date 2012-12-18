require "spec_helper"

describe "log" do

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
  end

  it "should get agent log" do
    with_tmpdir do
      with_deployment do
        bosh("logs batlight 0 --agent").should succeed_with /Logs saved in/
        files = tar_contents(tarfile)
        files.should include "./current"
      end
    end
  end

  it "should get cpi log" do
    pending "bosh logs --soap"
  end

  it "should get job logs" do
    with_tmpdir do
      with_deployment do
        bosh("logs batlight 0").should succeed_with /Logs saved in/
        files = tar_contents(tarfile)
        files.should include "./batlight/batlight.stdout.log"
        files.should include "./batlight/batlight.stderr.log"
      end
    end
  end
end
