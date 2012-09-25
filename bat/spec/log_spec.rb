require "spec_helper"
require "tmpdir"

describe "log" do

  before(:all) do
    bosh!("upload release #{latest_bat_release}")
    bosh!("upload stemcell #{stemcell}")
    bosh!("deployment #{deployment}")
    bosh!("deploy")
  end

  after(:all) do
    bosh!("delete deployment bat")
    bosh!("delete stemcell bosh-stemcell #{stemcell_version}")
    bosh!("delete release bat")
  end

  before(:each) do
    @tmp = Dir.mktmpdir
    @back = Dir.pwd
    Dir.chdir(@tmp)
  end

  after(:each) do
    Dir.chdir(@back)
    FileUtils.rm_rf(@tmp)
  end

  it "should get agent log" do
    bosh("logs batarang 0 --agent").should succeed_with /Logs saved in/
    # verify contents
  end

  it "should get cpi log" do
    pending "bosh logs --soap"
  end

  it "should get job logs" do
    bosh("logs batarang 0").should succeed_with /Logs saved in/
    # verify contents
  end
end