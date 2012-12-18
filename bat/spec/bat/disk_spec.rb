# Copyright (c) 2012 VMware, Inc.

require "spec_helper"

describe "persistent disk" do

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

  it "should create a disk" do
    use_static_ip
    use_job("batarang")
    use_persistent_disk(2048)
    with_deployment do
      persistent_disk(static_ip).should_not be_nil
    end
  end

  it "should migrate disk contents" do
    use_static_ip
    use_job("batarang")
    size = nil

    use_persistent_disk(2048)
    deployment = with_deployment
    bosh("deployment #{deployment.to_path}")
    bosh("deploy")

    ssh(static_ip, "vcap", password, "echo 'foobar' > #{SAVE_FILE}")
    size = persistent_disk(static_ip)
    size.should_not be_nil

    use_persistent_disk(4096)
    with_deployment do
      persistent_disk(static_ip).should_not == size
      ssh(static_ip, "vcap", password, "cat #{SAVE_FILE}").should match /foobar/
    end
    deployment.delete
  end
end
