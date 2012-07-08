require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::CompileTask do

  def make(package, stemcell)
    BD::CompileTask.new(package, stemcell)
  end

  describe "compilation readiness" do
    it "can tell if compiled" do
      package = BD::Models::Package.make(:name => "foo")
      stemcell = BD::Models::Stemcell.make
      compiled_package = BD::Models::CompiledPackage.make(:package => package)

      task = make(package, stemcell)
      task.ready_to_compile?.should be_true
      task.compiled?.should be_false

      task.use_compiled_package(compiled_package)
      task.compiled?.should be_true
      task.ready_to_compile?.should be_false # Already compiled!
    end

    it "is ready to compile when all dependencies are compiled" do
      package = BD::Models::Package.make(:name => "foo")
      stemcell = BD::Models::Stemcell.make
      compiled_package = BD::Models::CompiledPackage.make

      dep1 = BD::Models::Package.make(:name => "bar")
      dep2 = BD::Models::Package.make(:name => "baz")

      task = make(package, stemcell)
      dep1_task = make(dep1, stemcell)
      dep2_task = make(dep2, stemcell)

      task.add_dependency(dep1_task)
      task.add_dependency(dep2_task)

      task.all_dependencies_compiled?.should be_false
      dep1_task.use_compiled_package(compiled_package)
      task.all_dependencies_compiled?.should be_false
      dep2_task.use_compiled_package(compiled_package)
      task.all_dependencies_compiled?.should be_true
      task.ready_to_compile?.should be_true
    end
  end

  describe "adding dependencies" do
    it "works both ways" do
      stemcell = BD::Models::Stemcell.make
      foo = BD::Models::Package.make(:name => "foo")
      bar = BD::Models::Package.make(:name => "bar")
      baz = BD::Models::Package.make(:name => "baz")

      foo_task = make(foo, stemcell)
      bar_task = make(bar, stemcell)
      baz_task = make(baz, stemcell)

      foo_task.dependencies.should == []
      bar_task.dependent_tasks.should == []

      foo_task.add_dependency(bar_task)
      foo_task.dependencies.should == [bar_task]
      bar_task.dependent_tasks.should == [foo_task]

      baz_task.add_dependent_task(foo_task)
      baz_task.dependent_tasks.should == [foo_task]
      foo_task.dependencies.should == [bar_task, baz_task]
    end
  end

  describe "using compiled package" do
    it "registers compiled package with job" do
      package = BD::Models::Package.make
      stemcell = BD::Models::Stemcell.make

      cp = BD::Models::CompiledPackage.make
      cp2 = BD::Models::CompiledPackage.make

      task = make(package, stemcell)

      job_a = mock(BD::DeploymentPlan::Job)
      job_b = mock(BD::DeploymentPlan::Job)

      job_a.should_receive(:use_compiled_package).with(cp)
      job_b.should_receive(:use_compiled_package).with(cp)

      task.use_compiled_package(cp)
      task.add_job(job_a)
      task.add_job(job_b)

      task.jobs.should == [job_a, job_b]

      job_a.should_receive(:use_compiled_package).with(cp2)
      job_b.should_receive(:use_compiled_package).with(cp2)
      task.use_compiled_package(cp2)
    end
  end

  describe "generating dependency spec" do
    it "generates dependency spec" do
      stemcell = BD::Models::Stemcell.make
      foo = BD::Models::Package.make(:name => "foo")
      bar = BD::Models::Package.make(:name => "bar", :version => "42")
      cp = BD::Models::CompiledPackage.make(:package => bar, :build => 152,
                                            :sha1 => "deadbeef",
                                            :blobstore_id => "deadcafe")

      foo_task = make(foo, stemcell)
      bar_task = make(bar, stemcell)

      foo_task.add_dependency(bar_task)

      expect {
        foo_task.dependency_spec
      }.to raise_error(BD::DirectorError, /`bar' hasn't been compiled yet/i)

      bar_task.use_compiled_package(cp)

      foo_task.dependency_spec.should == {
        "bar" => {
          "name" => "bar",
          "version" => "42.152",
          "sha1" => "deadbeef",
          "blobstore_id" => "deadcafe"
        }
      }
    end

    it "doesn't include nested dependencies" do
      stemcell = BD::Models::Stemcell.make
      foo = BD::Models::Package.make(:name => "foo")
      bar = BD::Models::Package.make(:name => "bar", :version => "42")
      baz = BD::Models::Package.make(:name => "baz", :version => "17")

      cp_bar = BD::Models::CompiledPackage.
        make(:package => bar, :build => 152,
             :sha1 => "deadbeef",
             :blobstore_id => "deadcafe")

      cp_baz = BD::Models::CompiledPackage.
        make(:package => baz, :build => 335,
             :sha1 => "baddead",
             :blobstore_id => "deadbad")

      foo_task = make(foo, stemcell)
      bar_task = make(bar, stemcell)
      baz_task = make(baz, stemcell)

      foo_task.add_dependency(bar_task)
      bar_task.add_dependency(baz_task)

      foo_task.dependencies.should == [bar_task] # only includes immediate deps!
      bar_task.dependencies.should == [baz_task]

      bar_task.use_compiled_package(cp_bar)

      foo_task.dependency_spec.should == {
        "bar" => {
          "name" => "bar",
          "version" => "42.152",
          "sha1" => "deadbeef",
          "blobstore_id" => "deadcafe"
        }
      }
    end
  end
end
