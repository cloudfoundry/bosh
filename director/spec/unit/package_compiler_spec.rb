require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Director::PackageCompiler do

  describe "compile" do

    before(:each) do
      @release = Bosh::Director::Models::Release.make
      @release_version = Bosh::Director::Models::ReleaseVersion.make(:release => @release)
      @template = Bosh::Director::Models::Template.make(:release => @release)
      @stemcell = Bosh::Director::Models::Stemcell.make(:cid => "stemcell-id")

      @network = mock("network")
      @deployment_plan = mock("deployment_plan")
      @resource_pool_spec = mock("resource_pool_spec")
      @release_spec = mock("release_spec")
      @stemcell_spec = mock("stemcell_spec")
      @compilation_config = mock("compilation_config")
      @job_spec = mock("job_spec")
      @template_spec = mock("template_spec")
      @cloud = mock("cloud")

      @deployment_plan.stub!(:release).and_return(@release_spec)
      @deployment_plan.stub!(:jobs).and_return([@job_spec])
      @deployment_plan.stub!(:compilation).and_return(@compilation_config)
      @deployment_plan.stub!(:name).and_return("test_deployment")

      @network.stub!(:name).and_return("network_a")

      @release_spec.stub!(:release_version).and_return(@release_version)

      @resource_pool_spec.stub!(:stemcell).and_return(@stemcell_spec)

      @stemcell_spec.stub!(:stemcell).and_return(@stemcell)
      @stemcell_spec.stub!(:name).and_return(@stemcell.name)

      @template_spec.stub!(:template).and_return(@template)

      @job_spec.stub!(:resource_pool).and_return(@resource_pool_spec)
      @job_spec.stub!(:template).and_return(@template_spec)
      @job_spec.stub!(:name).and_return("test_job_name")

      Bosh::Director::Config.stub!(:cloud).and_return(@cloud)
    end

    it "should only bind the packages if all of the packages are already compiled" do
      package = Bosh::Director::Models::Package.make
      @template_spec.stub!(:packages).and_return([package])
      @release_version.add_package(package)

      compiled_package = Bosh::Director::Models::CompiledPackage.make(:package => package,
                                                                      :stemcell => @stemcell,
                                                                      :dependency_key => "[]")
      @job_spec.should_receive(:add_package).with(package, compiled_package)
      package_compiler = Bosh::Director::PackageCompiler.new(@deployment_plan)
      package_compiler.compile
    end

    it "should compile a package if it's not already compiled" do
      package = Bosh::Director::Models::Package.make(:release => @release,
                                                     :name => "test_pkg",
                                                     :version => 33,
                                                     :blobstore_id => "package-blob",
                                                     :sha1 => "package sha1")
      @template_spec.stub!(:packages).and_return([package])
      @release_version.add_package(package)

      @compilation_config.stub!(:network).and_return(@network)
      @compilation_config.stub!(:workers).and_return(1)
      @compilation_config.stub!(:cloud_properties).and_return({"ram" => "2gb"})

      @network.should_receive(:allocate_dynamic_ip).and_return(255)
      @network.should_receive(:network_settings).with(255).and_return({"ip" => "1.2.3.4"})

      agent = mock("agent")
      Bosh::Director::AgentClient.should_receive(:new).with("agent-1").and_return(agent)

      @cloud.should_receive(:create_vm).with("agent-1", "stemcell-id", {"ram" => "2gb"},
                                             {"network_a" => {"ip" => "1.2.3.4"}}).and_return("vm-1")
      agent.should_receive(:wait_until_ready)
      agent.should_receive(:apply).with(({"resource_pool" => "package_compiler",
                                          "networks" => {"network_a" => {"ip" => "1.2.3.4"}},
                                          "deployment" => "test_deployment"})).and_return({"state" => "done"})
      agent.should_receive(:compile_package).with("package-blob", "package sha1", "test_pkg", "33.1", {}).
          and_return({
            "state" => "done",
            "result" => {"sha1" => "some sha 1",
                         "blobstore_id" => "some blobstore id"}
          })
      @cloud.should_receive(:delete_vm).with("vm-1")
      @network.should_receive(:release_dynamic_ip).with("1.2.3.4")

      compiled_package = nil
      @job_spec.should_receive(:add_package).with do |bound_package, bound_compiled_package|
        compiled_package = bound_compiled_package
        bound_package.should == package
        bound_compiled_package.package.should == package
        bound_compiled_package.stemcell.should == @stemcell
        bound_compiled_package.build.should == 1
        bound_compiled_package.sha1.should == "some sha 1"
        bound_compiled_package.blobstore_id.should == "some blobstore id"
        bound_compiled_package.dependency_key.should == "[]"
        true
      end

      package_compiler = Bosh::Director::PackageCompiler.new(@deployment_plan)
      package_compiler.stub!(:generate_agent_id).and_return("agent-1", "invalid")
      package_compiler.compile

      Bosh::Director::Models::CompiledPackage.all.should == [compiled_package]
    end

    it "should compile a package and it's dependencies" do
      dependent_package = Bosh::Director::Models::Package.make(:release => @release,
                                                     :name => "dependency",
                                                     :version => 77,
                                                     :blobstore_id => "dep-blb-id",
                                                     :sha1 => "dep-sha1")

      package = Bosh::Director::Models::Package.make(:release => @release,
                                                     :name => "test_pkg",
                                                     :version => 33,
                                                     :blobstore_id => "package-blob",
                                                     :sha1 => "package sha1")
      package.dependency_set = Set.new(["dependency"])
      package.save

      @template_spec.stub!(:packages).and_return([package])
      @release_version.add_package(dependent_package)
      @release_version.add_package(package)

      @compilation_config.stub!(:network).and_return(@network)
      @compilation_config.stub!(:workers).and_return(1)
      @compilation_config.stub!(:cloud_properties).and_return({"ram" => "2gb"})

      @network.should_receive(:allocate_dynamic_ip).and_return(255)
      @network.should_receive(:network_settings).with(255).and_return({"ip" => "1.2.3.4"})

      agent_a = mock("agent")
      Bosh::Director::AgentClient.should_receive(:new).with("agent-a").and_return(agent_a)

      @cloud.should_receive(:create_vm).with("agent-a", "stemcell-id", {"ram" => "2gb"},
                                             {"network_a" => {"ip" => "1.2.3.4"}}).and_return("vm-1")
      agent_a.should_receive(:wait_until_ready)
      agent_a.should_receive(:apply).with(({"resource_pool" => "package_compiler",
                                            "networks" => {"network_a" => {"ip" => "1.2.3.4"}},
                                            "deployment" => "test_deployment"})).and_return({"state" => "done"})
      agent_a.should_receive(:compile_package).with("dep-blb-id", "dep-sha1", "dependency", "77.1", {}).
          and_return({
            "state" => "done",
            "result" => {"sha1" => "compiled-dep-sha1",
                         "blobstore_id" => "compiled-dep-blb-id"}
          })

      @cloud.should_receive(:delete_vm).with("vm-1")

      agent_b = mock("agent-b")
      Bosh::Director::AgentClient.should_receive(:new).with("agent-b").and_return(agent_b)

      @cloud.should_receive(:create_vm).with("agent-b", "stemcell-id", {"ram" => "2gb"},
                                             {"network_a" => {"ip" => "1.2.3.4"}}).and_return("vm-2")

      agent_b.should_receive(:wait_until_ready)
      agent_b.should_receive(:apply).with(({"resource_pool" => "package_compiler",
                                           "networks" => {"network_a" => {"ip" => "1.2.3.4"}},
                                           "deployment" => "test_deployment"})).and_return({"state" => "done"})

      agent_b.should_receive(:compile_package).with("package-blob", "package sha1", "test_pkg", "33.1",
                                                    {"dependency" => {"name" => "dependency",
                                                                      "blobstore_id" => "compiled-dep-blb-id",
                                                                      "sha1" => "compiled-dep-sha1",
                                                                      "version" => "77.1"}}).
          and_return({
            "state" => "done",
            "result" => {"sha1" => "compiled-sha1",
                         "blobstore_id" => "compiled-blb-id"}
          })

      @cloud.should_receive(:delete_vm).with("vm-2")
      @network.should_receive(:release_dynamic_ip).with("1.2.3.4")

      compiled_package = nil
      @job_spec.should_receive(:add_package).with do |bound_package, bound_compiled_package|
        compiled_package = bound_compiled_package
        bound_package.should == package
        bound_compiled_package.package.should == package
        bound_compiled_package.stemcell.should == @stemcell
        bound_compiled_package.build.should == 1
        bound_compiled_package.sha1.should == "compiled-sha1"
        bound_compiled_package.blobstore_id.should == "compiled-blb-id"
        bound_compiled_package.dependency_key.should == "[[\"dependency\",\"77\"]]"
        true
      end

      package_compiler = Bosh::Director::PackageCompiler.new(@deployment_plan)
      package_compiler.stub!(:generate_agent_id).and_return("agent-a", "agent-b", "invalid")
      package_compiler.compile

      dep_compiled_package = Bosh::Director::Models::CompiledPackage[:package_id => dependent_package.id]
      dep_compiled_package.should_not be_nil
      dep_compiled_package.package.should == dependent_package
      dep_compiled_package.stemcell.should == @stemcell
      dep_compiled_package.build.should == 1
      dep_compiled_package.sha1.should == "compiled-dep-sha1"
      dep_compiled_package.blobstore_id.should == "compiled-dep-blb-id"
      dep_compiled_package.dependency_key.should == "[]"

      Bosh::Director::Models::CompiledPackage.all.should =~ [compiled_package, dep_compiled_package]
    end
  end

end
