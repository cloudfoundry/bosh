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

  it "should set vcap password", ssh: true do
    # using password 'foobar'
    use_password('$6$tHAu4zCTso$pAQok0MTHP4newel7KMhTzMI4tQrAWwJ.X./fFAKjbWkCb5sAaavygXAspIGWn8qVD8FeT.Z/XN4dvqKzLHhl0')
    use_static_ip
    with_deployment do
      ssh(static_ip, "vcap", "echo foobar | sudo -S whoami", ssh_options.merge(password: "foobar")).should == "[sudo] password for vcap: root\n"
    end
  end

  it "should survive agent dying", ssh: true do
    use_static_ip

    Dir.mktmpdir do |tmpdir|
      with_deployment do
        ssh(static_ip, "vcap", "echo #{password} | sudo -S pkill -9 agent", ssh_options)
        # wait for agent to restart
        sleep(5)
        bosh("logs batlight 0 --agent --dir #{tmpdir}")
        # TODO check log for 2 agent starts (first is initial start and second is after crash)
      end
    end
  end
end
