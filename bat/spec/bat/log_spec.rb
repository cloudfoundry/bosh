require "spec_helper"
require "tmpdir"

describe "log" do

  before(:all) do
    bosh("upload release #{latest_bat_release}")
    bosh("upload stemcell #{stemcell}")
  end

  after(:all) do
    bosh("delete deployment bat")
    bosh("delete stemcell bosh-stemcell #{stemcell_version}")
    bosh("delete release bat")
  end

  around do |example|
    with_deployment(deployment_spec) do |deployment|
      bosh("deployment #{deployment}")
      bosh("deploy")
      example.run
    end
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
    files = tar_contents(tarfile)
    files.should include "./current"
  end

  it "should get cpi log" do
    pending "bosh logs --soap"
  end

  it "should get job logs" do
    bosh("logs batarang 0").should succeed_with /Logs saved in/
    files = tar_contents(tarfile)
    files.should include "./batarang/batarang.stdout.log"
    files.should include "./batarang/batarang.stderr.log"
  end
end