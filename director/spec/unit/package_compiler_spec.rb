require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Director::PackageCompiler do

  def create_package(name, id, version, release, blobstore_id, sha1, dependencies)
    package = stub("package-#{name}")
    package.stub!(:id).and_return(id)
    package.stub!(:name).and_return(name)
    package.stub!(:version).and_return(version)
    package.stub!(:release).and_return(release)
    package.stub!(:blobstore_id).and_return(blobstore_id)
    package.stub!(:sha1).and_return(sha1)
    package.stub!(:dependency_set).and_return(Set.new(dependencies))
    package
  end

  describe "compile" do

    before(:each) do
      @release = mock("release")
      @release_version = mock("release_version")
      @template = mock("template")
      @network = mock("network")
      @deployment_plan = mock("deployment_plan")
      @resource_pool_spec = mock("resource_pool_spec")
      @release_spec = mock("release_spec")
      @stemcell_spec = mock("stemcell_spec")
      @compilation_config = mock("compilation_config")
      @job_spec = mock("job_spec")
      @cloud = mock("cloud")
      @stemcell = mock("stemcell")

      @deployment_plan.stub!(:release).and_return(@release_spec)
      @deployment_plan.stub!(:jobs).and_return([@job_spec])
      @deployment_plan.stub!(:compilation).and_return(@compilation_config)
      @deployment_plan.stub!(:name).and_return("test_deployment")

      @network.stub!(:name).and_return("network_a")

      @release_spec.stub!(:release_version).and_return(@release_version)

      @resource_pool_spec.stub!(:stemcell).and_return(@stemcell_spec)

      @stemcell_spec.stub!(:stemcell).and_return(@stemcell)
      @stemcell_spec.stub!(:name).and_return("test_stemcell")

      @job_spec.stub!(:resource_pool).and_return(@resource_pool_spec)
      @job_spec.stub!(:template).and_return(@template)
      @job_spec.stub!(:name).and_return("test_job_name")

      @release.stub!(:name).and_return("test_release")

      @release_version.stub!(:id).and_return(42)

      @template.stub!(:name).and_return("test_job")

      @stemcell.stub!(:id).and_return(24)
      @stemcell.stub!(:cid).and_return("stemcell-id")
      @stemcell.stub!(:name).and_return("stemcell-name")
      @stemcell.stub!(:version).and_return("stemcell-version")

      Bosh::Director::Config.stub!(:cloud).and_return(@cloud)
    end

    it "should do nothing if all of the packages are already compiled" do
      package = create_package("test_pkg", 7, 33, @release, "package-blob", "package sha1", [])
      @template.stub!(:packages).and_return([package])
      @release_version.stub!(:packages).and_return([package])

      compiled_package = mock("compiled_package")
      compiled_package.stub!(:id).and_return(40)

      Bosh::Director::Models::CompiledPackage.stub!(:find).with(:package_id => 7,
                                                                :dependency_key=>"[]",
                                                                :stemcell_id => 24).
          and_return([compiled_package])
      package_compiler = Bosh::Director::PackageCompiler.new(@deployment_plan)
      package_compiler.compile
    end

    it "should compile a package if it's not already compiled" do
      package = create_package("test_pkg", 7, 33, @release, "package-blob", "package sha1", [])
      @template.stub!(:packages).and_return([package])
      @release_version.stub!(:packages).and_return([package])

      @compilation_config.stub!(:network).and_return(@network)
      @compilation_config.stub!(:workers).and_return(1)
      @compilation_config.stub!(:cloud_properties).and_return({"ram" => "2gb"})

      @network.should_receive(:allocate_dynamic_ip).and_return(255)
      @network.should_receive(:network_settings).with(255).and_return({"ip" => "1.2.3.4"})

      Bosh::Director::Models::CompiledPackage.stub!(:find).with(:package_id => 7,
                                                                :dependency_key=>"[]",
                                                                :stemcell_id => 24).
          and_return([])

      agent = mock("agent")
      Bosh::Director::AgentClient.should_receive(:new).with("agent-1").and_return(agent)

      @cloud.should_receive(:create_vm).with("agent-1", "stemcell-id", {"ram"=>"2gb"},
                                             {"network_a"=>{"ip"=>"1.2.3.4"}}).and_return("vm-1")
      agent.should_receive(:wait_until_ready)
      agent.should_receive(:apply).with(({"resource_pool"=>"package_compiler",
                                          "networks"=>{"network_a"=>{"ip"=>"1.2.3.4"}},
                                          "deployment"=>"test_deployment"})).and_return({"state" => "done"})
      agent.should_receive(:compile_package).with("package-blob", "package sha1", "test_pkg", 33, {}).
          and_return({
            "state" => "done",
            "result" => {"sha1" => "some sha 1",
                         "blobstore_id" => "some blobstore id"}
          })
      @cloud.should_receive(:delete_vm).with("vm-1")
      @network.should_receive(:release_dynamic_ip).with("1.2.3.4")

      compiled_package = mock("compiled_package")
      Bosh::Director::Models::CompiledPackage.should_receive(:new).
          with(:package => package,
               :stemcell => @stemcell,
               :sha1 => "some sha 1",
               :blobstore_id => "some blobstore id",
               :dependency_key => "[]").
          and_return(compiled_package)
      compiled_package.should_receive(:save!)
      compiled_package.stub!(:blobstore_id).and_return("some blobstore id")

      package_compiler = Bosh::Director::PackageCompiler.new(@deployment_plan)
      package_compiler.stub!(:generate_agent_id).and_return("agent-1", "invalid")
      package_compiler.compile
    end

    it "should compile a package and it's dependencies" do
      dependent_package = create_package("dependency", 44, 77, @release, "dep-blb-id", "dep-sha1", [])
      package = create_package("test_pkg", 7, 33, @release, "package-blob", "package sha1", [])
      package.stub!(:dependency_set).and_return(Set.new(["dependency"]))

      @template.stub!(:packages).and_return([package])
      @release_version.stub!(:packages).and_return([package, dependent_package])

      @compilation_config.stub!(:network).and_return(@network)
      @compilation_config.stub!(:workers).and_return(1)
      @compilation_config.stub!(:cloud_properties).and_return({"ram" => "2gb"})

      @network.should_receive(:allocate_dynamic_ip).and_return(255)
      @network.should_receive(:network_settings).with(255).and_return({"ip" => "1.2.3.4"})

      Bosh::Director::Models::CompiledPackage.stub!(:find).with(:package_id => 7,
                                                                :stemcell_id => 24,
                                                                :dependency_key=>"[[\"dependency\",77]]").
          and_return([])

      agent_a = mock("agent")
      Bosh::Director::AgentClient.should_receive(:new).with("agent-a").and_return(agent_a)

      @cloud.should_receive(:create_vm).with("agent-a", "stemcell-id", {"ram"=>"2gb"},
                                             {"network_a"=>{"ip"=>"1.2.3.4"}}).and_return("vm-1")
      agent_a.should_receive(:wait_until_ready)
      agent_a.should_receive(:apply).with(({"resource_pool"=>"package_compiler",
                                            "networks"=>{"network_a"=>{"ip"=>"1.2.3.4"}},
                                            "deployment"=>"test_deployment"})).and_return({"state" => "done"})
      agent_a.should_receive(:compile_package).with("dep-blb-id", "dep-sha1", "dependency", 77, {}).
          and_return({
            "state" => "done",
            "result" => {"sha1" => "compiled-dep-sha1",
                         "blobstore_id" => "compiled-dep-blb-id"}
          })

      @cloud.should_receive(:delete_vm).with("vm-1")

      agent_b = mock("agent-b")
      Bosh::Director::AgentClient.should_receive(:new).with("agent-b").and_return(agent_b)

      @cloud.should_receive(:create_vm).with("agent-b", "stemcell-id", {"ram"=>"2gb"},
                                             {"network_a"=>{"ip"=>"1.2.3.4"}}).and_return("vm-2")

      agent_b.should_receive(:wait_until_ready)
      agent_b.should_receive(:apply).with(({"resource_pool"=>"package_compiler",
                                           "networks"=>{"network_a"=>{"ip"=>"1.2.3.4"}},
                                           "deployment"=>"test_deployment"})).and_return({"state" => "done"})

      agent_b.should_receive(:compile_package).with("package-blob", "package sha1", "test_pkg", 33,
                                                    {"dependency" => {"name"=>"dependency",
                                                                      "blobstore_id" => "compiled-dep-blb-id",
                                                                      "sha1" => "compiled-dep-sha1",
                                                                      "version" => 77}}).
          and_return({
            "state" => "done",
            "result" => {"sha1" => "compiled-sha1",
                         "blobstore_id" => "compiled-blb-id"}
          })

      @cloud.should_receive(:delete_vm).with("vm-2")
      @network.should_receive(:release_dynamic_ip).with("1.2.3.4")

      Bosh::Director::Models::CompiledPackage.stub!(:find).with(:package_id => 44,
                                                                :stemcell_id => 24,
                                                                :dependency_key=>"[]").
          and_return([])

      dependent_compiled_package = mock("dep-compiled-package")
      dependent_compiled_package.should_receive(:save!)
      dependent_compiled_package.stub!(:blobstore_id).and_return("compiled-dep-blb-id")
      dependent_compiled_package.stub!(:sha1).and_return("compiled-dep-sha1")

      compiled_package = mock("compiled-package")
      compiled_package.should_receive(:save!)

      Bosh::Director::Models::CompiledPackage.should_receive(:new).
          with(:package => dependent_package,
               :stemcell => @stemcell,
               :sha1 => "compiled-dep-sha1",
               :blobstore_id => "compiled-dep-blb-id",
               :dependency_key => "[]").
          and_return(dependent_compiled_package)

      Bosh::Director::Models::CompiledPackage.should_receive(:new).
          with(:package => package,
               :stemcell => @stemcell,
               :sha1 => "compiled-sha1",
               :blobstore_id => "compiled-blb-id",
               :dependency_key => "[[\"dependency\",77]]").
          and_return(compiled_package)

      package_compiler = Bosh::Director::PackageCompiler.new(@deployment_plan)
      package_compiler.stub!(:generate_agent_id).and_return("agent-a", "agent-b", "invalid")
      package_compiler.compile
    end
  end

end
