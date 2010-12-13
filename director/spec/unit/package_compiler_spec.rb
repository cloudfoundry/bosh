require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Director::PackageCompiler do

  before(:each) do
    @logger = Logger.new(nil)
    Bosh::Director::Config.stub!(:logger).and_return(@logger)
  end

  describe "basic cases" do

    before(:each) do
      @release = mock("release")
      @release_version = mock("release_version")
      @template = mock("template")
      @package = mock("package")
      @network = mock("network")
      @agent = mock("agent")
      @deployment_plan = mock("deployment_plan")
      @resource_pool_spec = mock("resource_pool_spec")
      @release_spec = mock("release_spec")
      @stemcell_spec = mock("stemcell_spec")
      @compilation_config = mock("compilation_config")
      @job_spec = mock("job_spec")
      @cloud = mock("cloud")
      @stemcell = mock("stemcell")
      @packages = mock("packages")

      @deployment_plan.stub!(:release).and_return(@release_spec)
      @deployment_plan.stub!(:jobs).and_return([@job_spec])
      @deployment_plan.stub!(:compilation).and_return(@compilation_config)

      @network.stub!(:name).and_return("network_a")

      @release_spec.stub!(:release_version).and_return(@release_version)

      @resource_pool_spec.stub!(:stemcell).and_return(@stemcell_spec)

      @stemcell_spec.stub!(:stemcell).and_return(@stemcell)

      @job_spec.stub!(:resource_pool).and_return(@resource_pool_spec)
      @job_spec.stub!(:template).and_return("test_job")
      @job_spec.stub!(:packages).and_return(@packages)

      @template.stub!(:packages).and_return([@package])

      @release.stub!(:name).and_return("test_release")

      @release_version.stub!(:id).and_return(42)

      @template.stub!(:name).and_return("test_job")

      @package.stub!(:id).and_return(7)
      @package.stub!(:name).and_return("test_pkg")
      @package.stub!(:version).and_return(33)
      @package.stub!(:release).and_return(@release)
      @package.stub!(:blobstore_id).and_return("package-id")
      @package.stub!(:sha1).and_return("test_pkg source sha1")

      @stemcell.stub!(:id).and_return(24)
      @stemcell.stub!(:cid).and_return("stemcell-id")
      @stemcell.stub!(:name).and_return("stemcell-name")
      @stemcell.stub!(:version).and_return("stemcell-version")
      @stemcell.stub!(:compilation_resources).and_return({"ram" => "2gb"})

      Bosh::Director::Models::Template.stub!(:find).with(:release_version_id => 42,
                                                         :name => "test_job").and_return([@template])
      Bosh::Director::Config.stub!(:cloud).and_return(@cloud)
    end

    it "should do nothing if all of the packages are already compiled" do
      compiled_package = mock("compiled_package")

      Bosh::Director::Models::CompiledPackage.stub!(:find).with(:package_id => 7,
                                                                :stemcell_id => 24).and_return([compiled_package])
      @packages.should_receive(:[]=).with("test_pkg", 33)
      package_compiler = Bosh::Director::PackageCompiler.new(@deployment_plan)
      package_compiler.compile
    end

    it "should compile a package if it's not already compiled" do
      @compilation_config.stub!(:network).and_return(@network)
      @compilation_config.stub!(:workers).and_return(1)

      @network.should_receive(:allocate_dynamic_ip).and_return(255)
      @network.should_receive(:network_settings).with(255).and_return({"ip" => "1.2.3.4"})

      Bosh::Director::Models::CompiledPackage.stub!(:find).with(:package_id => 7,
                                                                :stemcell_id => 24).and_return([])
      Bosh::Director::AgentClient.should_receive(:new).with("agent-1").and_return(@agent)

      @packages.should_receive(:[]=).with("test_pkg", 33)

      @cloud.should_receive(:create_vm).with("agent-1", "stemcell-id", {"ram"=>"2gb"},
                                             {"network_a"=>{"ip"=>"1.2.3.4"}}).and_return("vm-1")
      @agent.should_receive(:wait_until_ready)
      @agent.should_receive(:compile_package).with("package-id", "test_pkg source sha1", "test_pkg", 33).and_return(
              {"state" => "done",
               "result" => {"sha1" => "some sha 1",
                            "blobstore_id" => "some blobstore id"}
              })
      @cloud.should_receive(:delete_vm).with("vm-1")
      @network.should_receive(:release_dynamic_ip).with("1.2.3.4")

      compiled_package = mock("compiled_package")
      Bosh::Director::Models::CompiledPackage.should_receive(:new).and_return(compiled_package)
      compiled_package.should_receive(:package=).with(@package)
      compiled_package.should_receive(:stemcell=).with(@stemcell)
      compiled_package.should_receive(:sha1=).with("some sha 1")
      compiled_package.should_receive(:blobstore_id=).with("some blobstore id")
      compiled_package.should_receive(:save!)
      compiled_package.stub!(:blobstore_id).and_return("some blobstore id")

      package_compiler = Bosh::Director::PackageCompiler.new(@deployment_plan)
      package_compiler.stub!(:generate_agent_id).and_return("agent-1", "invalid")
      package_compiler.compile
    end
  end

  describe "compilation settings" do

    it "should respect the number of workers" do
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

      release.stub!(:name).and_return("test_release")
      network.stub!(:name).and_return("network_a")

      package_a.stub!(:name).and_return("a")
      package_a.stub!(:version).and_return(1)
      package_a.stub!(:sha1).and_return("sha1-a")
      package_a.stub!(:blobstore_id).and_return("package-a-id")
      package_a.stub!(:release).and_return(release)

      package_b.stub!(:name).and_return("b")
      package_b.stub!(:version).and_return(2)
      package_b.stub!(:sha1).and_return("sha1-b")
      package_b.stub!(:blobstore_id).and_return("package-b-id")
      package_b.stub!(:release).and_return(release)

      stemcell_a.stub!(:cid).and_return("stemcell_a")
      stemcell_a.stub!(:name).and_return("stemcell-a-name")
      stemcell_a.stub!(:version).and_return("stemcell-a-version")
      stemcell_a.stub!(:compilation_resources).and_return({"ram" => "2gb"})

      stemcell_b.stub!(:cid).and_return("stemcell_b")
      stemcell_b.stub!(:name).and_return("stemcell-b-name")
      stemcell_b.stub!(:version).and_return("stemcell-b-version")
      stemcell_b.stub!(:compilation_resources).and_return({"ram" => "2gb"})

      deployment_plan.stub!(:compilation).and_return(compilation_config)
      compilation_config.stub!(:network).and_return(network)
      compilation_config.stub!(:workers).and_return(1)
      network.should_receive(:allocate_dynamic_ip).and_return(255)
      network.should_receive(:network_settings).with(255).and_return({"ip" => "1.2.3.4"})

      Bosh::Director::Config.stub!(:cloud).and_return(cloud)

      package_compiler = Bosh::Director::PackageCompiler.new(deployment_plan)
      package_compiler.should_receive(:find_uncompiled_packages).and_return([
        {:package => package_a, :stemcell => stemcell_a},
        {:package => package_b, :stemcell => stemcell_b}
      ])

      package_compiler.stub!(:generate_agent_id).and_return("agent-1", "agent-2", "invalid")

      cloud.should_receive(:create_vm).with("agent-1", "stemcell_a", {"ram"=>"2gb"},
                                            {"network_a"=>{"ip"=>"1.2.3.4"}}).and_return("vm-1")

      cloud.should_receive(:create_vm).with("agent-2", "stemcell_b", {"ram"=>"2gb"},
                                            {"network_a"=>{"ip"=>"1.2.3.4"}}).and_return("vm-2")

      Bosh::Director::AgentClient.should_receive(:new).with("agent-1").and_return(agent_a)
      Bosh::Director::AgentClient.should_receive(:new).with("agent-2").and_return(agent_b)

      compiled_package = mock("compiled_package")
      compiled_package.stub!(:package=)
      compiled_package.stub!(:stemcell=)
      compiled_package.stub!(:sha1=)
      compiled_package.stub!(:blobstore_id=)
      compiled_package.stub!(:save!)
      compiled_package.stub!(:blobstore_id).and_return("compiled blobstore id")

      Bosh::Director::Models::CompiledPackage.stub!(:new).and_return(compiled_package)

      agent_a.should_receive(:wait_until_ready)
      agent_a.should_receive(:compile_package).with("package-a-id", "sha1-a", "a", 1).and_return(
              {"state" => "done",
               "result" => {"sha1" => "some sha a",
                            "blobstore_id" => "some blobstore a"}
              })
      agent_b.should_receive(:wait_until_ready)
      agent_b.should_receive(:compile_package).with("package-b-id", "sha1-b", "b", 2).and_return(
              {"state" => "done",
               "result" => {"sha1" => "some sha b",
                            "blobstore_id" => "some blobstore b"}
              })

      cloud.should_receive(:delete_vm).with("vm-1")
      cloud.should_receive(:delete_vm).with("vm-2")

      network.should_receive(:release_dynamic_ip).with("1.2.3.4")

      package_compiler.compile
    end

  end

end
