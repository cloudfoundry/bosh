# Copyright (c) 2012 VMware, Inc.

require "spec_helper"

describe "persistent disk" do
  SAVE_FILE = "/var/vcap/store/batarang/save"

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

  xit "should create a disk" do
    pending "failing on ci - Address 10.10.0.32 is in use."
    use_static_ip
    use_job("batarang")
    use_persistent_disk(2048)
    with_deployment do
      persistent_disk(static_ip).should_not be_nil
    end
  end

  it "should migrate disk contents", ssh: true do
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
