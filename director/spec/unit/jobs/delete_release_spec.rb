require File.dirname(__FILE__) + '/../../spec_helper'

describe Bosh::Director::Jobs::DeleteRelease do

  before(:each) do
    @blobstore = mock("blobstore")
    Bosh::Director::Config.stub!(:blobstore).and_return(@blobstore)
  end

  describe "perform" do

    it "should fail for unknown releases" do
      lock = stub("lock")
      Bosh::Director::Lock.stub!(:new).with("lock:release:test_release", :timeout => 10).
          and_return(lock)
      lock.should_receive(:lock).and_yield

      job = Bosh::Director::Jobs::DeleteRelease.new("test_release")
      lambda { job.perform }.should raise_exception(Bosh::Director::ReleaseNotFound)
    end

    it "should fail if the deployments still reference this release" do

      release = Bosh::Director::Models::Release.make(:name => "test_release")
      Bosh::Director::Models::Deployment.make(:name => "test_deployment", :release => release)

      lock = stub("lock")
      Bosh::Director::Lock.stub!(:new).with("lock:release:test_release", :timeout => 10).
          and_return(lock)
      lock.should_receive(:lock).and_yield

      job = Bosh::Director::Jobs::DeleteRelease.new("test_release")
      lambda { job.perform }.should raise_exception(Bosh::Director::ReleaseInUse)
    end

    it "should delete the release and associated jobs, packages, compiled packages and their metadata" do
      release = Bosh::Director::Models::Release.make(:name => "test_release")

      lock = stub("lock")
      Bosh::Director::Lock.stub!(:new).with("lock:release:test_release", :timeout => 10).
          and_return(lock)
      lock.should_receive(:lock).and_yield

      job = Bosh::Director::Jobs::DeleteRelease.new("test_release")
      job.should_receive(:delete_release).with(release)
      job.perform
    end

    it "should fail if the delete was not successful" do
      release = Bosh::Director::Models::Release.make(:name => "test_release")

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
      @release = Bosh::Director::Models::Release.make(:name => "test_release")
      @release_version = Bosh::Director::Models::ReleaseVersion.make(:release => @release)
      @package = Bosh::Director::Models::Package.make(:release => @release, :blobstore_id => "package-blb")
      @template = Bosh::Director::Models::Template.make(:release => @release, :blobstore_id => "template-blb")
      @stemcell = Bosh::Director::Models::Stemcell.make
      @compiled_package = Bosh::Director::Models::CompiledPackage.make(:package => @package, :stemcell => @stemcell,
                                                                       :blobstore_id => "compiled-package-blb")
      @release_version.add_package(@package)
      @release_version.add_template(@template)
    end

    it "should delete release and associated objects/meta" do
      @blobstore.should_receive(:delete).with("template-blb")
      @blobstore.should_receive(:delete).with("package-blb")
      @blobstore.should_receive(:delete).with("compiled-package-blb")

      job = Bosh::Director::Jobs::DeleteRelease.new("test_release")
      job.delete_release(@release)

      job.instance_eval {@errors}.should be_empty

      Bosh::Director::Models::Release[@release.id].should be_nil
      Bosh::Director::Models::ReleaseVersion[@release_version.id].should be_nil
      Bosh::Director::Models::Package[@package.id].should be_nil
      Bosh::Director::Models::Template[@template.id].should be_nil
      Bosh::Director::Models::CompiledPackage[@compiled_package.id].should be_nil
    end

    it "should fail to delete the release if there is a blobstore error" do
      @blobstore.should_receive(:delete).with("template-blb").and_raise("bad")
      @blobstore.should_receive(:delete).with("package-blb")
      @blobstore.should_receive(:delete).with("compiled-package-blb")

      job = Bosh::Director::Jobs::DeleteRelease.new("test_release")
      job.delete_release(@release)

      errors = job.instance_eval {@errors}
      errors.length.should eql(1)
      errors.first.to_s.should eql("bad")

      Bosh::Director::Models::Release[@release.id].should_not be_nil
      Bosh::Director::Models::ReleaseVersion[@release_version.id].should_not be_nil
      Bosh::Director::Models::Package[@package.id].should be_nil
      Bosh::Director::Models::Template[@template.id].should_not be_nil
      Bosh::Director::Models::CompiledPackage[@compiled_package.id].should be_nil
    end

    it "should forcefully delete the release when requested even if there is a blobstore error" do
      @blobstore.should_receive(:delete).with("template-blb").and_raise("bad")
      @blobstore.should_receive(:delete).with("package-blb")
      @blobstore.should_receive(:delete).with("compiled-package-blb")

      job = Bosh::Director::Jobs::DeleteRelease.new("test_release", "force" => true)
      job.delete_release(@release)

      errors = job.instance_eval {@errors}
      errors.length.should eql(1)
      errors.first.to_s.should eql("bad")

      Bosh::Director::Models::Release[@release.id].should be_nil
      Bosh::Director::Models::ReleaseVersion[@release_version.id].should be_nil
      Bosh::Director::Models::Package[@package.id].should be_nil
      Bosh::Director::Models::Template[@template.id].should be_nil
      Bosh::Director::Models::CompiledPackage[@compiled_package.id].should be_nil
    end

  end

end
