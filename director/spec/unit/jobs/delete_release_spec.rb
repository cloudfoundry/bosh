require File.dirname(__FILE__) + '/../../spec_helper'

describe Bosh::Director::Jobs::DeleteRelease do

  before(:each) do
    @blobstore = mock("blobstore")
    Bosh::Director::Config.stub!(:blobstore).and_return(@blobstore)
  end

  describe "perform" do

    it "should fail for unknown releases" do
      Bosh::Director::Models::Release.stub!(:find).with(:name => "test_release").
          and_return([])

      lock = stub("lock")
      Bosh::Director::Lock.stub!(:new).with("lock:release:test_release", :timeout => 10).
          and_return(lock)
      lock.should_receive(:lock).and_yield

      job = Bosh::Director::Jobs::DeleteRelease.new("test_release")
      lambda { job.perform }.should raise_exception(Bosh::Director::ReleaseNotFound)
    end

    it "should fail if the deployments still reference this release" do
      deployment = stub("deployment")
      deployment.stub!(:name).and_return("test_deployment")

      release = stub("release")
      release.stub!(:name).and_return("test_release")
      release.stub!(:deployments).and_return(Set.new([deployment]))

      Bosh::Director::Models::Release.stub!(:find).with(:name => "test_release").and_return([release])

      lock = stub("lock")
      Bosh::Director::Lock.stub!(:new).with("lock:release:test_release", :timeout => 10).
          and_return(lock)
      lock.should_receive(:lock).and_yield

      job = Bosh::Director::Jobs::DeleteRelease.new("test_release")
      lambda { job.perform }.should raise_exception(Bosh::Director::ReleaseInUse)
    end

    it "should delete the release and associated jobs, packages, compiled packages and their metadata" do
      deployment = stub("deployment")
      deployment.stub!(:name).and_return("test_deployment")

      release = stub("release")
      release.stub!(:name).and_return("test_release")
      release.stub!(:deployments).and_return(Set.new([]))

      Bosh::Director::Models::Release.stub!(:find).with(:name => "test_release").and_return([release])

      lock = stub("lock")
      Bosh::Director::Lock.stub!(:new).with("lock:release:test_release", :timeout => 10).
          and_return(lock)
      lock.should_receive(:lock).and_yield

      job = Bosh::Director::Jobs::DeleteRelease.new("test_release")
      job.should_receive(:delete_release).with(release)
      job.perform
    end

    it "should fail if the delete was not successful" do
      deployment = stub("deployment")
      deployment.stub!(:name).and_return("test_deployment")

      release = stub("release")
      release.stub!(:name).and_return("test_release")
      release.stub!(:deployments).and_return(Set.new([]))

      Bosh::Director::Models::Release.stub!(:find).with(:name => "test_release").and_return([release])

      lock = stub("lock")
      Bosh::Director::Lock.stub!(:new).with("lock:release:test_release", :timeout => 10).
          and_return(lock)
      lock.should_receive(:lock).and_yield

      job = Bosh::Director::Jobs::DeleteRelease.new("test_release")
      job.should_receive(:delete_release).with(release)
      job.instance_eval { @errors << "bad" }
      lambda { job.perform }.should raise_exception
    end

  end

  describe "delete_release" do

    before(:each) do
      @release = stub("release")
      @release_version = stub("release_version")
      @package = stub("package")
      @compiled_package = stub("compiled_package")
      @template = stub("template")
      @stemcell = stub("stemcell")

      @template.stub!(:blobstore_id).and_return("template-blb")
      @template.stub!(:name).and_return("template_name")
      @template.stub!(:version).and_return("2")

      @package.stub!(:blobstore_id).and_return("package-blb")
      @package.stub!(:name).and_return("package_name")
      @package.stub!(:version).and_return("3")
      @package.stub!(:compiled_packages).and_return([@compiled_package])

      @stemcell.stub!(:name).and_return("stemcell_name")
      @stemcell.stub!(:version).and_return("4")

      @compiled_package.stub!(:blobstore_id).and_return("compiled-package-blb")
      @compiled_package.stub!(:stemcell).and_return(@stemcell)

      @release_version.stub!(:version).and_return("1")
      @release_version.stub!(:packages).and_return([@package])
      @release_version.stub!(:templates).and_return([@template])

      @release.stub!(:versions).and_return([@release_version])
    end

    it "should delete release and associated objects/meta" do
      @blobstore.should_receive(:delete).with("template-blb")
      @blobstore.should_receive(:delete).with("package-blb")
      @blobstore.should_receive(:delete).with("compiled-package-blb")

      @release.should_receive(:delete)
      @release_version.should_receive(:delete)
      @template.should_receive(:delete)
      @package.should_receive(:delete)
      @compiled_package.should_receive(:delete)

      job = Bosh::Director::Jobs::DeleteRelease.new("test_release")
      job.delete_release(@release)
    end

    it "should fail to delete the release if there is a blobstore error" do
      @blobstore.should_receive(:delete).with("template-blb").and_raise("bad")
      @blobstore.should_receive(:delete).with("package-blb")
      @blobstore.should_receive(:delete).with("compiled-package-blb")

      @release.should_not_receive(:delete)
      @release_version.should_not_receive(:delete)
      @template.should_not_receive(:delete)
      @package.should_receive(:delete)
      @compiled_package.should_receive(:delete)

      job = Bosh::Director::Jobs::DeleteRelease.new("test_release")
      job.delete_release(@release)

      errors = job.instance_eval {@errors}
      errors.length.should eql(1)
      errors.first.to_s.should eql("bad")
    end

    it "should forcefully delete the release when requested even if there is a blobstore error" do
      @blobstore.should_receive(:delete).with("template-blb").and_raise("bad")
      @blobstore.should_receive(:delete).with("package-blb")
      @blobstore.should_receive(:delete).with("compiled-package-blb")

      @release.should_receive(:delete)
      @release_version.should_receive(:delete)
      @template.should_receive(:delete)
      @package.should_receive(:delete)
      @compiled_package.should_receive(:delete)

      job = Bosh::Director::Jobs::DeleteRelease.new("test_release", "force" => true)
      job.delete_release(@release)

      errors = job.instance_eval {@errors}
      errors.length.should eql(1)
      errors.first.to_s.should eql("bad")
    end

  end

end
