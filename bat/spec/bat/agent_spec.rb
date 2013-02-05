# Copyright (c) 2012 VMware, Inc.

require "spec_helper"

describe "agent" do

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

  it "should set vcap password" do
    # using password 'foobar'
    use_password('$6$tHAu4zCTso$pAQok0MTHP4newel7KMhTzMI4tQrAWwJ.X./fFAKjbWkCb5sAaavygXAspIGWn8qVD8FeT.Z/XN4dvqKzLHhl0')
    use_static_ip
    with_deployment do
      ssh(static_ip, "vcap", "foobar", "cat /etc/hosts").should_not == ""
    end
  end

  it "should survive agent dying" do
    use_static_ip

    Dir.mktmpdir do |tmpdir|
      with_deployment do
        ssh(static_ip, "root", password, "pkill -9 agent")
        # wait for agent to restart
        sleep(5)
        bosh("logs batlight 0 --agent --dir #{tmpdir}")
      end
    end
  end
end
