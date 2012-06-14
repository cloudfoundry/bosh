# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

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
      release = Bosh::Director::Models::Release.make(:name => "test")
      version = Bosh::Director::Models::ReleaseVersion.
        make(:release => release, :version => "42-dev")
      deployment = Bosh::Director::Models::Deployment.make(:name => "test")

      deployment.add_release_version(version)

      lock = stub("lock")
      Bosh::Director::Lock.stub!(:new).with("lock:release:test",
                                            :timeout => 10).and_return(lock)
      lock.should_receive(:lock).and_yield

      job = Bosh::Director::Jobs::DeleteRelease.new("test")
      lambda {
        job.perform
      }.should raise_exception(Bosh::Director::ReleaseInUse)
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

    it "should support deleting a particular release version" do
      release = Bosh::Director::Models::Release.make(:name => "test_release")
      rv1 = Bosh::Director::Models::ReleaseVersion.make(:release => release, :version => "1")
      rv2 = Bosh::Director::Models::ReleaseVersion.make(:release => release, :version => "2")

      lock = stub("lock")
      lock.should_receive(:lock).and_yield

      Bosh::Director::Lock.stub!(:new).with("lock:release:test_release", :timeout => 10).and_return(lock)

      job = Bosh::Director::Jobs::DeleteRelease.new("test_release", "version" => rv1.version)
      job.should_receive(:delete_release_version).with(rv1)
      job.perform
    end

    it "should fail deleting version if there is a deployment which uses that version" do
      release = Bosh::Director::Models::Release.make(:name => "test_release")
      rv1 = Bosh::Director::Models::ReleaseVersion.make(:release => release, :version => "1")
      rv2 = Bosh::Director::Models::ReleaseVersion.make(:release => release, :version => "2")

      manifest = YAML.dump("release" => { "name" => "test_release", "version" => "2"})

      deployment = Bosh::Director::Models::Deployment.make(:name => "test_deployment", :manifest => manifest)
      deployment.add_release_version(rv2)

      lock = stub("lock")
      Bosh::Director::Lock.stub!(:new).with("lock:release:test_release", :timeout => 10).and_return(lock)
      lock.stub!(:lock).and_yield

      job1 = Bosh::Director::Jobs::DeleteRelease.new("test_release", "version" => "2")

      lambda {
        job1.perform
      }.should raise_exception(Bosh::Director::ReleaseVersionInUse)

      job2 = Bosh::Director::Jobs::DeleteRelease.new("test_release", "version" => "1")
      job2.should_receive(:delete_release_version).with(rv1)
      job2.perform
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

  describe "delete release version" do
    before(:each) do
      @release = Bosh::Director::Models::Release.make(:name => "test_release")

      @rv1 = Bosh::Director::Models::ReleaseVersion.make(:release => @release)
      @rv2 = Bosh::Director::Models::ReleaseVersion.make(:release => @release)

      @pkg1 = Bosh::Director::Models::Package.make(:release => @release, :blobstore_id => "pkg1")
      @pkg2 = Bosh::Director::Models::Package.make(:release => @release, :blobstore_id => "pkg2")
      @pkg3 = Bosh::Director::Models::Package.make(:release => @release, :blobstore_id => "pkg3")

      @tmpl1 = Bosh::Director::Models::Template.make(:release => @release, :blobstore_id => "template1")
      @tmpl2 = Bosh::Director::Models::Template.make(:release => @release, :blobstore_id => "template2")
      @tmpl3 = Bosh::Director::Models::Template.make(:release => @release, :blobstore_id => "template3")

      @stemcell = Bosh::Director::Models::Stemcell.make

      @cpkg1 = Bosh::Director::Models::CompiledPackage.make(:package => @pkg1, :stemcell => @stemcell, :blobstore_id => "deadbeef")
      @cpkg2 = Bosh::Director::Models::CompiledPackage.make(:package => @pkg2, :stemcell => @stemcell, :blobstore_id => "badcafe")
      @cpkg3 = Bosh::Director::Models::CompiledPackage.make(:package => @pkg3, :stemcell => @stemcell, :blobstore_id => "feeddead")

      @rv1.add_package(@pkg1)
      @rv1.add_package(@pkg2)
      @rv1.add_package(@pkg3)

      @rv2.add_package(@pkg1)
      @rv2.add_package(@pkg2)

      @rv1.add_template(@tmpl1)
      @rv1.add_template(@tmpl2)
      @rv1.add_template(@tmpl3)

      @rv2.add_template(@tmpl1)
      @rv2.add_template(@tmpl2)
    end

    it "should delete release version without touching any shared packages/templates" do
      job = Bosh::Director::Jobs::DeleteRelease.new("test_release", "version" => @rv1.version)

      @blobstore.should_receive(:delete).with("pkg3")
      @blobstore.should_receive(:delete).with("template3")
      @blobstore.should_receive(:delete).with("feeddead")

      job.delete_release_version(@rv1)

      Bosh::Director::Models::ReleaseVersion[@rv1.id].should be_nil
      Bosh::Director::Models::ReleaseVersion[@rv2.id].should_not be_nil

      Bosh::Director::Models::Package[@pkg1.id].should == @pkg1
      Bosh::Director::Models::Package[@pkg2.id].should == @pkg2
      Bosh::Director::Models::Package[@pkg3.id].should be_nil

      Bosh::Director::Models::Template[@tmpl1.id].should == @tmpl1
      Bosh::Director::Models::Template[@tmpl2.id].should == @tmpl2
      Bosh::Director::Models::Template[@tmpl3.id].should be_nil

      Bosh::Director::Models::CompiledPackage[@cpkg1.id].should == @cpkg1
      Bosh::Director::Models::CompiledPackage[@cpkg2.id].should == @cpkg2
      Bosh::Director::Models::CompiledPackage[@cpkg3.id].should be_nil
    end

    it "should not leave any release/package/templates artefacts after all release versions have been deleted" do
      job1 = Bosh::Director::Jobs::DeleteRelease.new("test_release", "version" => @rv1.version)
      job2 = Bosh::Director::Jobs::DeleteRelease.new("test_release", "version" => @rv2.version)

      @blobstore.stub!(:delete)

      lock = stub("lock")
      Bosh::Director::Lock.stub!(:new).with("lock:release:test_release", :timeout => 10).
        and_return(lock)
      lock.should_receive(:lock).exactly(2).times.and_yield

      job1.perform

      Bosh::Director::Models::Release.count.should == 1

      # This assertion is very important as SQLite doesn't check integrity
      # but Postgres does and it can fail on postgres if there are any hanging
      # references to release version in packages_release_versions
      Bosh::Director::Models::Package.db[:packages_release_versions].count.should == 2

      job2.perform

      Bosh::Director::Models::ReleaseVersion.count.should == 0
      Bosh::Director::Models::Package.count.should == 0
      Bosh::Director::Models::Template.count.should  == 0
      Bosh::Director::Models::CompiledPackage.count.should == 0
      Bosh::Director::Models::Release.count.should == 0
    end

  end

end
