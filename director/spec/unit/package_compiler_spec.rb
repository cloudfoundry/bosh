require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Director::PackageCompiler do

  it "should compile packages" do
    deployment_plan = mock("deployment_plan")
    release = mock("release")
    package_a = mock("package_a")
    package_b = mock("package_b")
    stemcell_a = mock("stemcell_a")
    stemcell_b = mock("stemcell_b")
    cloud = mock("cloud")
    compilation_config = mock("compilation_config")
    network = mock("network")
    agent_a = mock("agent_a")
    agent_b = mock("agent_b")

    Bosh::Director::Config.stub!(:cloud).and_return(cloud)

    release.stub!(:name).and_return("test_release")

    package_a.stub!(:name).and_return("a")
    package_a.stub!(:version).and_return(1)
    package_a.stub!(:sha1).and_return("sha1-a")
    package_a.stub!(:release).and_return(release)

    package_b.stub!(:name).and_return("b")
    package_b.stub!(:version).and_return(2)
    package_b.stub!(:sha1).and_return("sha1-b")
    package_b.stub!(:release).and_return(release)

    stemcell_a.stub!(:cid).and_return("stemcell_a")
    stemcell_a.stub!(:compilation_resources).and_return({"ram" => "2gb"})

    stemcell_b.stub!(:cid).and_return("stemcell_b")
    stemcell_b.stub!(:compilation_resources).and_return({"ram" => "2gb"})

    deployment_plan.stub!(:compilation).and_return(compilation_config)
    compilation_config.stub!(:network).and_return(network)
    compilation_config.stub!(:workers).and_return(1)
    network.should_receive(:allocate_dynamic_ip).and_return(255)
    network.should_receive(:network_settings).with(255).and_return({"ip" => "1.2.3.4"})

    uncompiled_packages = [{:package => package_a, :stemcell => stemcell_a},
                           {:package => package_b, :stemcell => stemcell_b}]

    package_compiler = Bosh::Director::PackageCompiler.new(deployment_plan, uncompiled_packages)

    package_compiler.stub!(:generate_agent_id).and_return("agent-1", "agent-2", "invalid")

    cloud.should_receive(:create_vm).with("agent-1", "stemcell_a", {"ram"=>"2gb"},
                                          {"ip"=>"1.2.3.4"}).and_return("vm-1")

    cloud.should_receive(:create_vm).with("agent-2", "stemcell_b", {"ram"=>"2gb"},
                                          {"ip"=>"1.2.3.4"}).and_return("vm-2")

    Bosh::Director::AgentClient.should_receive(:new).with("agent-1").and_return(agent_a)
    Bosh::Director::AgentClient.should_receive(:new).with("agent-2").and_return(agent_b)

    agent_a.should_receive(:compile_package).with("test_release", "a", 1, "sha1-a").and_return({"state" => "done"})
    agent_b.should_receive(:compile_package).with("test_release", "b", 2, "sha1-b").and_return({"state" => "done"})

    cloud.should_receive(:delete_vm).with("vm-1")
    cloud.should_receive(:delete_vm).with("vm-2")

    network.should_receive(:release_dynamic_ip).with("1.2.3.4")

    package_compiler.compile
  end

end