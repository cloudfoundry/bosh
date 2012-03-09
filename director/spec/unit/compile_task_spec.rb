require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::CompileTask do

  describe :dependencies_satisfied? do
    before(:each) do
      @task = BD::CompileTask.new("foo.bar")
      3.times { @task.dependencies << stub(:CompileTask) }
    end

    it "should return true if all dependencies have been compiled" do
      @task.dependencies.each do |dep|
        dep.stub(:compiled_package).and_return(BD::Models::CompiledPackage.make)
      end
      @task.dependencies_satisfied?.should == true
    end

    it "should return false if one of the dependencies was not compiled yet" do
      @task.dependencies.each_with_index do |dep, index|
        if index == 0
          dep.stub(:compiled_package).
              and_return(BD::Models::CompiledPackage.make)
        else
          dep.stub(:compiled_package).and_return(nil)
        end
      end
      @task.dependencies_satisfied?.should == false
    end
  end

  describe :ready_to_compile? do
    before(:each) do
      @task = BD::CompileTask.new("foo.bar")
    end

    it "should return true when it's ready" do
      @task.instance_eval { @compiled_package = nil }
      @task.stub(:dependencies_satisfied?).and_return(true)
      @task.ready_to_compile?.should == true
    end

    it "should return false if it's already compiled" do
      @task.instance_eval { @compiled_package = nil }
      @task.stub(:dependencies_satisfied?).and_return(true)
      @task.ready_to_compile?.should == true
    end

    it "should return false if the dependencies are not met" do
      @task.instance_eval { @compiled_package = nil }
      @task.stub(:dependencies_satisfied?).and_return(true)
      @task.ready_to_compile?.should == true
    end
  end

  describe :compiled_package= do
    it "should add the compiled package to all of the jobs waiting for this task" do
      task = BD::CompileTask.new("foo.bar")
      job = stub(:JobSpec)
      package = BD::Models::Package.make
      compiled_package = BD::Models::CompiledPackage.make(:package => package)
      task.jobs = [job]
      task.package = package

      job.should_receive(:add_package).with(package, compiled_package)

      task.compiled_package = compiled_package
    end
  end

  describe :add_job do
    it "should add the compiled package to the job if it was already compiled" do
      task = BD::CompileTask.new("foo.bar")
      package = BD::Models::Package.make
      compiled_package = BD::Models::CompiledPackage.make(:package => package)
      task.package = package
      task.compiled_package = compiled_package
      job = stub(:JobSpec)

      job.should_receive(:add_package).with(package, compiled_package)

      task.add_job(job)
    end
  end

  describe :dependency_spec do
    it "should generate empty Hash when there are no deps" do
      task = BD::CompileTask.new("foo.bar")
      task.dependency_spec.should == {}
    end

    it "should generate dependency spec for BOSH Agent compile_package call" do
      package = BD::Models::Package.make(:name => "foo", :version => "3")
      compiled_package = BD::Models::CompiledPackage.make(
          :package => package, :build => 22, :sha1 => "some sha",
          :blobstore_id => "some id")

      dep = BD::CompileTask.new("dep.baz")
      dep.package = package
      dep.compiled_package = compiled_package

      task = BD::CompileTask.new("foo.bar")
      task.dependencies << dep
      task.dependency_spec.should == {
          "foo" => {
              "name" => "foo",
              "version" => "3.22",
              "sha1" => "some sha",
              "blobstore_id" => "some id"
          }
      }
    end
  end
end
