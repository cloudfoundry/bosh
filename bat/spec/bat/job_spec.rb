# Copyright (c) 2012 VMware, Inc.

require "spec_helper"

describe "job" do

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

  it "should restart a job" do
    with_deployment do
      bosh("restart bat 0").should succeed_with %r{bat/0 has been restarted}
      # TODO verify that the process gets a new pid
    end
  end

  it "should recreate a job" do
    with_deployment do
      bosh("recreate bat 0").should succeed_with %r{bat/0 has been recreated}
      # TODO verify that the VM gets a new cid
    end
  end

  it "should stop and start a job" do
    with_deployment do
      bosh("stop bat 0").should succeed_with %r{bat/0 has been stopped}
      bosh("start bat 0").should succeed_with %r{bat/0 has been started}
      # TODO verify that the process gets a new pid
    end
  end

  it "should rename a job" do
    with_deployment do
      use_job("batfoo")
      use_template("batlight")
      updated_job_manifest = with_deployment
      bosh("deployment #{updated_job_manifest.to_path}").should succeed
      bosh('rename job batlight batfoo').should succeed_with %r{Rename successful}
      bosh('vms').should succeed_with %r{batfoo}
      updated_job_manifest.delete
    end
  end

end
